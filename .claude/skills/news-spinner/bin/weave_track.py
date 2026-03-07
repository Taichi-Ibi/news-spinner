#!/usr/bin/env python3
"""Log NewsSpinner fetch operations to W&B Weave."""

import argparse
import json
import logging
import sys
from pathlib import Path

LOG_FILE = Path(__file__).parent.parent / "runtime" / "weave_track.log"
LOG_FILE.parent.mkdir(parents=True, exist_ok=True)

_fmt = logging.Formatter("%(asctime)s %(levelname)s %(message)s")
_file_handler = logging.FileHandler(LOG_FILE)
_file_handler.setLevel(logging.DEBUG)
_file_handler.setFormatter(_fmt)
_stderr_handler = logging.StreamHandler(sys.stderr)
_stderr_handler.setLevel(logging.WARNING)
_stderr_handler.setFormatter(_fmt)

logger = logging.getLogger(__name__)
logger.setLevel(logging.DEBUG)
logger.addHandler(_file_handler)
logger.addHandler(_stderr_handler)

try:
    import weave
    logger.debug("weave package loaded successfully")
except ImportError:
    logger.warning("weave package not installed — skipping")
    sys.exit(2)  # caller can detect this and suggest installation


@weave.op()
def log_fetch(
    # INPUT: what was requested
    keywords: list,
    since: str,
    fetched_at: str,
    source_feed: str,
    locale: dict,
    pool_size_before: int,
    added: int,
    pool_size_after: int,
    headlines_json_path: str,
) -> dict:
    # OUTPUT: what was retrieved
    new_headlines = []
    if headlines_json_path and Path(headlines_json_path).exists():
        try:
            new_headlines = json.loads(Path(headlines_json_path).read_text())
        except Exception:
            pass
    return {
        "keyword_count": len(keywords),
        "added": added,
        "pool_size_after": pool_size_after,
        "new_headlines": new_headlines,
    }


def main():
    from datetime import datetime, timezone

    parser = argparse.ArgumentParser()
    parser.add_argument("--keywords", nargs="+", default=[])
    parser.add_argument("--since", default="")
    parser.add_argument("--added", type=int, default=0)
    parser.add_argument("--pool-size-before", type=int, default=0)
    parser.add_argument("--pool-size-after", type=int, default=0)
    parser.add_argument("--config", default="")
    parser.add_argument("--headlines-json", default="")
    args = parser.parse_args()

    logger.info("Logging fetch: keywords=%s since=%r added=%d", args.keywords, args.since, args.added)

    locale = {"hl": "ja", "gl": "JP", "ceid": "JP:ja"}
    if args.config and Path(args.config).exists():
        try:
            cfg = json.loads(Path(args.config).read_text())
            params = cfg.get("default_params", {})
            locale = {
                "hl": params.get("hl", locale["hl"]),
                "gl": params.get("gl", locale["gl"]),
                "ceid": params.get("ceid", locale["ceid"]),
            }
        except Exception as e:
            logger.warning("Could not read config: %s", e)

    fetched_at = datetime.now(timezone.utc).isoformat()

    logger.debug("Initializing weave project 'news-spinner'")
    weave.init("news-spinner")

    result = log_fetch(
        keywords=args.keywords,
        since=args.since,
        fetched_at=fetched_at,
        source_feed="google_news_rss",
        locale=locale,
        pool_size_before=args.pool_size_before,
        added=args.added,
        pool_size_after=args.pool_size_after,
        headlines_json_path=args.headlines_json,
    )
    logger.info("Weave log_fetch completed: %s", json.dumps(result, ensure_ascii=False))


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        logger.exception("Unexpected error: %s", e)
        sys.exit(1)
