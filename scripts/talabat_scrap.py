#!/usr/bin/env python3
"""
talabat_scrap.py

Robust Talabat menu scraper (HTML -> __NEXT_DATA__ -> initialMenuState.menuData.items)

Enhancements included:
1) Works for ANY Talabat restaurant URL:
   - auto-detects branch_id from path: /<country>/restaurant/<branch_id>/<slug>
   - auto-detects aid (area id) from query (?aid=####)
2) Block/challenge detection + debug artifact:
   - if __NEXT_DATA__ missing OR menu path missing/empty -> saves HTML to debug_blocked.html
3) Retries + exponential backoff:
   - configurable retries/backoff/timeout
4) Clean normalized output:
   - sections + flat items
   - URL unescape (&amp;)
   - scraped_at timestamp
5) CLI features:
   - --url, --out, --format (json/csv), --pretty
   - --only-sections (repeatable), --min-price
6) Fingerprints/hashes:
   - item_hash per item (stable)
   - menu_hash for change detection

Usage:
  python talabat_scrap.py --url "https://www.talabat.com/egypt/restaurant/771378/balbaa?aid=7137"
  python talabat_scrap.py --url "..." --format json --pretty
  python talabat_scrap.py --url "..." --format csv --out menu.csv
  python talabat_scrap.py --url "..." --only-sections "Picks for you 🔥" --min-price 50
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import re
import sys
import time
from dataclasses import asdict, dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, Iterable, List, Optional, Tuple
from urllib.parse import parse_qs, urlparse

import requests


NEXT_DATA_RE = re.compile(
    r'<script[^>]*id="__NEXT_DATA__"[^>]*>(.*?)</script>',
    re.DOTALL | re.IGNORECASE,
)


# ---------- Data models ----------

@dataclass(frozen=True)
class TalabatItem:
    id: int
    name: str
    description: str
    price: float
    old_price: float
    rating: float
    image: str
    original_image: str
    has_choices: bool
    section_name: str
    section_id: int
    original_section: str
    is_item_discount: bool
    is_with_image: bool
    is_top_rated_item: bool
    item_hash: str  # stable fingerprint


# ---------- Helpers ----------

def now_utc_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def html_unescape_amp(s: str) -> str:
    return s.replace("&amp;", "&") if isinstance(s, str) else s


def sha256_hex(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8", errors="ignore")).hexdigest()


def safe_float(x: Any, default: float = 0.0) -> float:
    try:
        if x is None:
            return default
        return float(x)
    except Exception:
        return default


def safe_int(x: Any, default: int = -1) -> int:
    try:
        if x is None:
            return default
        return int(x)
    except Exception:
        return default


def normalize_ws(s: str) -> str:
    return " ".join((s or "").split()).strip()


def detect_blocked_html(html: str) -> Optional[str]:
    """
    Best-effort detection of challenge/blocked pages.
    Returns a short reason if suspicious, else None.
    """
    low = html.lower()
    if "__next_data__" not in low:
        # Could be a different template, but often indicates blocked/challenge
        if "cdn-cgi/challenge-platform" in low or "cf-ray" in low or "cloudflare" in low:
            return "Looks like a Cloudflare challenge page (no __NEXT_DATA__)."
        if "<title>" in low and "access denied" in low:
            return "Access denied page detected."
        return "No __NEXT_DATA__ found in HTML."
    return None


def save_debug_html(html: str, path: Path) -> None:
    path.write_text(html, encoding="utf-8", errors="ignore")


def parse_url_parts(url: str) -> Dict[str, Optional[str]]:
    """
    Extract:
      - country_slug
      - branch_id
      - branch_slug
      - aid (area id) if present
    """
    u = urlparse(url)
    qs = parse_qs(u.query or "")
    aid_list = qs.get("aid", [])
    aid = aid_list[0] if aid_list and len(aid_list) > 0 else None

    path = u.path.strip("/")
    parts = path.split("/") if path else []

    # Expected: <country>/restaurant/<branch_id>/<branch_slug>
    country_slug = parts[0] if len(parts) >= 1 else None
    branch_id = None
    branch_slug = None
    if len(parts) >= 4 and parts[1] == "restaurant":
        branch_id = parts[2] if len(parts) > 2 else None
        branch_slug = parts[3] if len(parts) > 3 else None

    return {
        "country_slug": country_slug,
        "branch_id": branch_id,
        "branch_slug": branch_slug,
        "aid": aid,
        "netloc": u.netloc,
        "path": u.path,
    }


# ---------- Network + Parsing ----------

def fetch_html_with_retries(
    url: str,
    timeout: int,
    retries: int,
    backoff: float,
    debug_path: Path,
) -> str:
    """
    Fetch HTML with retries and exponential backoff.
    Saves debug HTML if blocked.
    Uses session cookies by visiting homepage first to appear more human-like.
    """
    headers = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
        "Accept-Language": "en-US,en;q=0.9,ar;q=0.8",
        "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8",
        "Accept-Encoding": "gzip, deflate, br",
        "Cache-Control": "max-age=0",
        "Upgrade-Insecure-Requests": "1",
        "Sec-Fetch-Dest": "document",
        "Sec-Fetch-Mode": "navigate",
        "Sec-Fetch-Site": "none",
        "Sec-Fetch-User": "?1",
        "Connection": "keep-alive",
    }

    last_err: Optional[Exception] = None
    sess = requests.Session()
    
    # Visit homepage first to get cookies and appear more human-like
    try:
        homepage_url = "https://www.talabat.com/"
        sess.get(homepage_url, headers=headers, timeout=timeout, allow_redirects=True)
        time.sleep(0.5)  # Small delay to seem more human
    except Exception:
        pass  # Continue even if homepage visit fails

    for attempt in range(1, retries + 2):  # retries means extra attempts
        try:
            # Update referer for subsequent requests
            if attempt > 1:
                headers["Referer"] = "https://www.talabat.com/"
            
            resp = sess.get(url, headers=headers, timeout=timeout, allow_redirects=True)
            resp.raise_for_status()
            html = resp.text

            # Check if we got a valid response
            if len(html) < 1000:
                raise RuntimeError(f"Response too short ({len(html)} bytes), likely an error page")

            blocked_reason = detect_blocked_html(html)
            if blocked_reason:
                # Save for inspection
                save_debug_html(html, debug_path)
                
                # Check if it's a Cloudflare challenge
                if "cloudflare" in html.lower() or "cf-ray" in html.lower() or "challenge" in html.lower():
                    raise RuntimeError(
                        f"Cloudflare challenge detected. This usually means Talabat is blocking automated requests. "
                        f"HTML saved to {debug_path} for inspection. "
                        f"You may need to use a browser automation tool (like Selenium) or add delays between requests."
                    )
                
                raise RuntimeError(f"{blocked_reason} (Saved: {debug_path})")

            # Verify __NEXT_DATA__ exists
            if "__next_data__" not in html.lower():
                save_debug_html(html, debug_path)
                raise RuntimeError(
                    f"__NEXT_DATA__ not found in HTML. This could mean:\n"
                    f"1. Talabat is blocking the request (check {debug_path})\n"
                    f"2. The page structure has changed\n"
                    f"3. The URL is invalid or the restaurant doesn't exist\n"
                    f"HTML saved to {debug_path} for inspection."
                )

            return html

        except RuntimeError:
            # Re-raise RuntimeErrors (our custom errors)
            raise
        except Exception as e:
            last_err = e
            if attempt >= retries + 1:
                break
            sleep_s = backoff * (2 ** (attempt - 1))
            print(f"[warn] Fetch failed (attempt {attempt}/{retries+1}): {e}")
            print(f"[warn] Retrying in {sleep_s:.1f}s...")
            time.sleep(sleep_s)

    # Save last error HTML if available
    if last_err and hasattr(last_err, 'response') and hasattr(last_err.response, 'text'):
        save_debug_html(last_err.response.text, debug_path)
    
    raise RuntimeError(
        f"Failed to fetch page after {retries+1} attempts. Last error: {last_err}\n"
        f"If this persists, Talabat may be blocking automated requests. "
        f"Consider using browser automation (Selenium/Playwright) or adding longer delays."
    )


def extract_next_data(html: str) -> Dict[str, Any]:
    m = NEXT_DATA_RE.search(html)
    if not m:
        raise RuntimeError("__NEXT_DATA__ not found in HTML.")
    raw = m.group(1).strip()
    return json.loads(raw)


def parse_items(next_data: Dict[str, Any], debug_path: Path, raw_html_for_debug: Optional[str] = None) -> Tuple[List[TalabatItem], Dict[str, Any]]:
    """
    Extract items from:
      props.pageProps.initialMenuState.menuData.items
    Or try alternative paths if the structure has changed.
    """
    items_raw = []
    page_props = {}
    
    # Try primary path
    try:
        page_props = next_data.get("props", {}).get("pageProps", {})
        initial_menu_state = page_props.get("initialMenuState", {}) or {}
        menu_data = initial_menu_state.get("menuData", {}) or {}
        items_raw = menu_data.get("items", []) or []
    except Exception as e:
        pass  # Will try alternatives
    
    # Try alternative paths if primary path didn't work
    if not items_raw:
        # Alternative 1: Check if items are directly in initialMenuState
        try:
            initial_menu_state = page_props.get("initialMenuState", {}) or {}
            if "items" in initial_menu_state:
                items_raw = initial_menu_state.get("items", []) or []
        except:
            pass
    
    if not items_raw:
        # Alternative 2: Check if menuData is at a different level
        try:
            menu_data = page_props.get("menuData", {}) or {}
            items_raw = menu_data.get("items", []) or []
        except:
            pass
    
    if not items_raw:
        # Alternative 3: Search for items anywhere in pageProps
        try:
            def find_items_recursive(obj, depth=0, max_depth=5):
                """Recursively search for 'items' key"""
                if depth > max_depth:
                    return None
                if isinstance(obj, dict):
                    if "items" in obj and isinstance(obj["items"], list) and len(obj["items"]) > 0:
                        # Check if it looks like menu items (has name/price)
                        try:
                            first_item = obj["items"][0]
                            if isinstance(first_item, dict) and ("name" in first_item or "price" in first_item):
                                return obj["items"]
                        except (IndexError, KeyError, TypeError):
                            pass  # Skip if we can't access the first item
                    for value in obj.values():
                        result = find_items_recursive(value, depth + 1, max_depth)
                        if result:
                            return result
                elif isinstance(obj, list):
                    for item in obj:
                        result = find_items_recursive(item, depth + 1, max_depth)
                        if result:
                            return result
                return None
            
            items_raw = find_items_recursive(page_props) or []
        except:
            pass
    
    # If still no items, raise error with helpful info
    if not items_raw:
        if raw_html_for_debug is not None:
            save_debug_html(raw_html_for_debug, debug_path)
        
        # Provide helpful debug info
        debug_info = []
        try:
            debug_info.append(f"pageProps keys: {list(page_props.keys())}")
            if "initialMenuState" in page_props:
                debug_info.append(f"initialMenuState keys: {list(page_props['initialMenuState'].keys())}")
        except:
            pass
        
        error_msg = f"Menu items list is empty. Saved HTML to {debug_path} for inspection."
        if debug_info:
            error_msg += f" Debug: {'; '.join(debug_info)}"
        raise RuntimeError(error_msg)

    items: List[TalabatItem] = []
    for it in items_raw:
        # Skip if item is not a dictionary
        if not isinstance(it, dict):
            continue
        
        # Normalize strings and URLs
        _id = safe_int(it.get("id"))
        name = normalize_ws(str(it.get("name", "")))
        desc = normalize_ws(str(it.get("description", "")))
        price = safe_float(it.get("price", 0.0), 0.0)
        old_price = safe_float(it.get("oldPrice", -1), -1.0)
        rating = safe_float(it.get("rating", 0.0), 0.0)
        image = html_unescape_amp(normalize_ws(str(it.get("image", ""))))
        original_image = html_unescape_amp(normalize_ws(str(it.get("originalImage", ""))))
        has_choices = bool(it.get("hasChoices", False))
        section_name = normalize_ws(str(it.get("sectionName", "Uncategorized"))) or "Uncategorized"
        section_id = safe_int(it.get("sectionId", -1), -1)
        original_section = normalize_ws(str(it.get("originalSection", "")))
        is_item_discount = bool(it.get("isItemDiscount", False))
        is_with_image = bool(it.get("isWithImage", False))
        is_top_rated_item = bool(it.get("isTopRatedItem", False))

        # Stable fingerprint for change detection
        # (include fields that matter to your menu sync)
        item_fp = "|".join([
            str(_id),
            name.lower(),
            desc.lower(),
            f"{price:.2f}",
            f"{old_price:.2f}",
            image,
            original_image,
            str(has_choices),
            section_name.lower(),
        ])
        item_hash = sha256_hex(item_fp)

        items.append(
            TalabatItem(
                id=_id,
                name=name,
                description=desc,
                price=price,
                old_price=old_price,
                rating=rating,
                image=image,
                original_image=original_image,
                has_choices=has_choices,
                section_name=section_name,
                section_id=section_id,
                original_section=original_section,
                is_item_discount=is_item_discount,
                is_with_image=is_with_image,
                is_top_rated_item=is_top_rated_item,
                item_hash=item_hash,
            )
        )

    return items, page_props


def group_by_section(items: List[TalabatItem]) -> Dict[str, List[TalabatItem]]:
    grouped: Dict[str, List[TalabatItem]] = {}
    for it in items:
        grouped.setdefault(it.section_name, []).append(it)
    return grouped


def compute_menu_hash(items: List[TalabatItem]) -> str:
    """
    Menu hash based on sorted item hashes (stable across ordering differences).
    """
    combined = "\n".join(sorted(it.item_hash for it in items))
    return sha256_hex(combined)


# ---------- Filtering ----------

def apply_filters(
    items: List[TalabatItem],
    only_sections: Optional[List[str]],
    min_price: Optional[float],
) -> List[TalabatItem]:
    out = items

    if only_sections:
        allowed = {s.strip() for s in only_sections if s.strip()}
        out = [it for it in out if it.section_name in allowed]

    if min_price is not None:
        out = [it for it in out if it.price >= min_price]

    return out


# ---------- Output ----------

def build_output_json(
    url: str,
    url_info: Dict[str, Optional[str]],
    items: List[TalabatItem],
    grouped: Dict[str, List[TalabatItem]],
    page_props: Dict[str, Any],
) -> Dict[str, Any]:
    return {
        "source": "talabat",
        "scraped_at": now_utc_iso(),
        "restaurant_url": url,
        "url_info": url_info,
        "counts": {
            "items": len(items),
            "sections": len(grouped),
        },
        "hashes": {
            "menu_hash": compute_menu_hash(items),
        },
        "sections": [
            {
                "name": sec,
                "items": [asdict(it) for it in sec_items],
            }
            for sec, sec_items in sorted(grouped.items(), key=lambda x: (-len(x[1]), x[0]))
        ],
        "items": [asdict(it) for it in items],
        # Useful bits (not guaranteed stable; keep minimal)
        "meta": {
            "query": page_props.get("query") if isinstance(page_props.get("query"), dict) else None,
            "buildId": page_props.get("buildId") if "buildId" in page_props else None,
        },
    }


def write_json(path: Path, payload: Dict[str, Any], pretty: bool) -> None:
    path.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2 if pretty else None),
        encoding="utf-8",
    )


def write_csv(path: Path, items: List[TalabatItem]) -> None:
    """
    Flat CSV export (one row per item).
    """
    if not items:
        raise ValueError("Cannot write CSV: items list is empty")
    
    fieldnames = list(asdict(items[0]).keys())
    with path.open("w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=fieldnames)
        w.writeheader()
        for it in items:
            w.writerow(asdict(it))


def default_outfile(url_info: Dict[str, Optional[str]], fmt: str) -> str:
    branch_id = url_info.get("branch_id") or "unknown"
    slug = url_info.get("branch_slug") or "talabat"
    ext = "json" if fmt == "json" else "csv"
    return f"{slug}_{branch_id}_menu.{ext}"


# ---------- Main ----------

def main() -> None:
    parser = argparse.ArgumentParser(description="Scrape Talabat menu from embedded __NEXT_DATA__.")
    parser.add_argument(
        "--url",
        type=str,
        required=True,
        help="Talabat restaurant URL, e.g. https://www.talabat.com/egypt/restaurant/771378/balbaa?aid=7137",
    )
    parser.add_argument(
        "--format",
        choices=["json", "csv"],
        default="json",
        help="Output format",
    )
    parser.add_argument(
        "--out",
        type=str,
        default=None,
        help="Output file path (default derived from URL)",
    )
    parser.add_argument(
        "--pretty",
        action="store_true",
        help="Pretty JSON output (indent=2)",
    )
    parser.add_argument(
        "--timeout",
        type=int,
        default=30,
        help="HTTP timeout seconds",
    )
    parser.add_argument(
        "--retries",
        type=int,
        default=2,
        help="Number of retries (total attempts = retries + 1)",
    )
    parser.add_argument(
        "--backoff",
        type=float,
        default=1.0,
        help="Backoff base seconds (exponential)",
    )
    parser.add_argument(
        "--debug-html",
        type=str,
        default="debug_blocked.html",
        help="Where to save HTML on blocked/parse failure",
    )
    parser.add_argument(
        "--only-sections",
        action="append",
        default=None,
        help="Keep only these section names. Repeatable: --only-sections 'Picks for you 🔥' --only-sections 'Soups'",
    )
    parser.add_argument(
        "--min-price",
        type=float,
        default=None,
        help="Keep only items with price >= this value",
    )

    args = parser.parse_args()

    url = args.url.strip()
    debug_path = Path(args.debug_html)

    url_info = parse_url_parts(url)
    out_path = Path(args.out) if args.out else Path(default_outfile(url_info, args.format))

    html = fetch_html_with_retries(
        url=url,
        timeout=args.timeout,
        retries=args.retries,
        backoff=args.backoff,
        debug_path=debug_path,
    )

    # Parse
    try:
        next_data = extract_next_data(html)
        items, page_props = parse_items(next_data, debug_path=debug_path, raw_html_for_debug=html)
    except Exception as e:
        # Always save debug on hard failure
        save_debug_html(html, debug_path)
        print(f"[error] {e}")
        print(f"[error] Saved HTML to: {debug_path.resolve()}")
        sys.exit(2)

    # Filters
    items = apply_filters(items, only_sections=args.only_sections, min_price=args.min_price)

    # Grouping
    grouped = group_by_section(items)

    # Console summary
    print(f"Items: {len(items)}")
    if items:
        first = items[0]
        print(f"Sample: {first.name} | EGP {first.price:g} | section={first.section_name}")
    print("\nSections:")
    for sec, sec_items in sorted(grouped.items(), key=lambda x: (-len(x[1]), x[0])):
        print(f"- {sec}: {len(sec_items)}")

    # Output
    if args.format == "json":
        payload = build_output_json(
            url=url,
            url_info=url_info,
            items=items,
            grouped=grouped,
            page_props=page_props,
        )
        write_json(out_path, payload, pretty=args.pretty)
    else:
        write_csv(out_path, items)

    print(f"\nWrote: {out_path.resolve()}")
    sys.exit(0)


if __name__ == "__main__":
    main()
