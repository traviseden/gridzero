#!/usr/bin/env python3
"""Static-site sanity check: local links/assets, structure, and no scripts."""
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import urlparse

ROOT = Path(__file__).resolve().parents[1] / "site"
VOID = {"area", "base", "br", "col", "embed", "hr", "img", "input", "link", "meta", "param", "source", "track", "wbr"}

class Check(HTMLParser):
    def __init__(self, file):
        super().__init__(convert_charrefs=True)
        self.file = file
        self.stack = []
        self.title = False
        self.main = False

    def handle_starttag(self, tag, attrs):
        values = dict(attrs)
        assert tag != "script", f"Scripts aren't needed: {self.file}"
        assert not any(key.startswith("on") for key in values), "Inline event handler"
        self.title |= tag == "title"
        self.main |= tag == "main"
        if tag == "img":
            assert "alt" in values and "width" in values and "height" in values
        for key in ("src", "href", "srcset"):
            link = values.get(key, "")
            url = urlparse(link)
            if url.scheme or url.netloc or not url.path:
                continue
            target = ROOT / url.path.lstrip("/") if url.path.startswith("/") else self.file.parent / url.path
            if target.is_dir():
                target /= "index.html"
            assert target.is_file(), f"Broken local {key}: {self.file}: {link}"
        if tag not in VOID:
            self.stack.append(tag)

    def handle_endtag(self, tag):
        assert self.stack and self.stack.pop() == tag, f"Unbalanced {tag}: {self.file}"

for file in ROOT.rglob("*.html"):
    parser = Check(file)
    parser.feed(file.read_text())
    assert not parser.stack and parser.title and parser.main, f"Incomplete HTML: {file}"
    print(f"Checked {file.relative_to(ROOT)}")
print("Static site links, images, structure, and script-free pages verified")
