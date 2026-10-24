# Usage: python3 -I gallery.py <run-dir> <gallery-out-dir> <current-round, e.g. r3>
# Reads <run>/rN/manifest.jsonl + <run>/rN/<card>/{card.png,index.html}; needs Pillow.
# Why a viewer: Artifact links to sibling .html files don't open, so cards load via fetch + iframe srcdoc.
import sys, json, html, glob, os, re, shutil, subprocess
from PIL import Image

R, G, CUR = sys.argv[1].rstrip('/'), sys.argv[2], sys.argv[3]
SLUG = re.sub(r'^\d{4}-\d{2}-\d{2}-', '', os.path.basename(R)).replace('-', ' ').strip().title() or 'Gallery'
os.makedirs(G + '/thumbs', exist_ok=True)
os.makedirs(G + '/cards', exist_ok=True)

def load(r):
    return sorted([json.loads(l) for l in open(f'{R}/{r}/manifest.jsonl')], key=lambda c: c['id'])

def stage(r, prefix):
    for d in sorted(glob.glob(f'{R}/{r}/*/')):
        n = os.path.basename(d.rstrip('/'))
        im = Image.open(d + 'card.png').convert('RGB'); w, h = im.size
        im = im.crop((0, 0, w, min(h, int(w * 900 / 1440)))); im.thumbnail((1600, 1600))
        im.save(f'{G}/thumbs/{prefix}{n}.jpg', quality=78)
        shutil.copy(d + 'index.html', f'{G}/cards/{prefix}{n}.html')

cur = load(CUR)
stage(CUR, CUR + '-')
older = []
for r in sorted((os.path.basename(p) for p in glob.glob(f'{R}/r[0-9]*')), key=lambda x: -int(x[1:])):
    if r != CUR and os.path.exists(f'{R}/{r}/manifest.jsonl'):
        older.append((r, load(r)))
        stage(r, r + '-')

tiers = [('mild', 1), ('medium', 2), ('bold', 3), ('wild', 4), ('wilder', 5)]

def card(c, r, small=False):
    f = r + '-' + c['src'].split('/')[1]
    br = (f'<p class="body-sm"><span class="os-chip os-chip--fill label">breaks</span> {html.escape(c["breaks"])}</p>' if c['breaks'] else '')
    lab = f'{c["id"]} · {html.escape(c["name"])}'
    return (f'<article class="os-sheet card{" sm" if small else ""}" id="{r}-c{c["id"]}">'
            f'<button class="shot" type="button" data-src="cards/{f}.html" data-label="{lab}">'
            f'<img src="thumbs/{f}.jpg" alt="Card {c["id"]}, {html.escape(c["name"])}" loading="lazy"></button>'
            f'<div class="cap"><div class="label">{c["id"]}</div><h3 class="subhead">{html.escape(c["name"])}</h3>'
            f'<p class="body-sm os-muted">{html.escape(c["idea"])}</p>{br}'
            f'<button class="open label" type="button" data-src="cards/{f}.html" data-label="{lab}">View full page</button></div></article>')

def rows(cards, r, small=False):
    out = ''
    for t, i in tiers:
        cs = [c for c in cards if c['tier'] == t]
        if not cs:
            continue
        ids = f'<span class="os-chip os-chip--fill label">{" ".join(c["id"] for c in cs)}</span>'
        grid = f'<div class="grid">{"".join(card(c, r, small) for c in cs)}</div>'
        if small:
            out += f'<div class="old-tier" id="{r}-{t}"><h3 class="subhead">{t.capitalize()} {ids}</h3>{grid}</div>'
        else:
            out += (f'<section class="os-sec" id="{r}-{t}"><h2 class="os-sh heading">{t.capitalize()}</h2>'
                    f'<div>{ids}</div>{grid}</section>')
    return out

def rng(t):
    ids = [c['id'] for c in cur if c['tier'] == t]
    return f'{ids[0]}–{ids[-1]}' if ids else ''

ladder = ''.join(f'<li><button type="button" data-jump="{CUR}-{t}"><b class="label">{t.capitalize()}</b><span class="caption">{rng(t)}</span></button></li>' for t, i in tiers)
hist = ''.join(f'<details class="os-disclosure"><summary class="heading">Round {r[1:]}<span class="os-chip os-chip--fill label">{len(cs)} cards</span></summary><div class="inner">{rows(cs, r, True)}</div></details>' for r, cs in older)
HEAD_PY = os.path.expanduser(os.environ.get('MILD2WILD_HEAD', '~/.claude/skills/artifact-house-style/head.py'))
# Used when no house-style kit is installed: defines the tokens and os-*/type classes the markup uses.
FALLBACK_HEAD = """<style>
:root{--page:#fff;--layer-1:#f7f7f8;--layer-2:#efeff1;--line:rgba(0,0,0,.12);--line-strong:#1d1d1f;--text:#1d1d1f;--text-muted:#6e6e73;--accent:#1d1d1f;
--space-4:4px;--space-8:8px;--space-12:12px;--space-16:16px;--space-24:24px;--space-32:32px;--space-48:48px;
--radius-panel:10px;--radius-control:6px;--radius-round:9999px;--line-width:1px;--ring-width:2px;
--font-sans:system-ui,-apple-system,"Helvetica Neue",sans-serif;--font-mono:ui-monospace,Menlo,monospace;color-scheme:light dark}
@media (prefers-color-scheme:dark){:root{--page:#0b0b0c;--layer-1:#161617;--layer-2:#1f1f21;--line:rgba(255,255,255,.16);--line-strong:#f5f5f7;--text:#f5f5f7;--text-muted:#a1a1a6;--accent:#f5f5f7}}
body{background:var(--page);color:var(--text);font-family:var(--font-sans);margin:0;line-height:1.5}
.title{font-size:2rem;line-height:1.15;margin:0}.heading{font-size:1.25rem;margin:0}.subhead{font-size:1rem;margin:0}
.lead{font-size:1.125rem;margin:0}.body-sm{font-size:.875rem;margin:0}.caption{font-size:.75rem}
.label{font-size:.75rem;text-transform:uppercase;letter-spacing:.04em}
.os-container{max-width:1600px;margin:0 auto;padding:var(--space-32) var(--space-16)}
.os-doc,.os-front,.os-evidence{display:flex;flex-direction:column;gap:var(--space-32)}
.os-masthead{display:flex;flex-direction:column;gap:var(--space-8)}
.os-meta,.os-muted{color:var(--text-muted)}
.os-sheet{background:var(--layer-1);border:var(--line-width) solid var(--line);border-radius:var(--radius-panel);padding:var(--space-16)}
.os-cols{display:grid;gap:var(--space-16)}.os-cols--3{grid-template-columns:repeat(auto-fit,minmax(220px,1fr))}
.os-sec{display:flex;flex-direction:column;gap:var(--space-12)}.os-sh{margin:0}
.os-chip{display:inline-block;padding:0 var(--space-8);border:var(--line-width) solid var(--line);border-radius:var(--radius-round)}
.os-chip--fill{background:var(--layer-2)}
.os-scale{list-style:none;margin:0;padding:0;display:grid;grid-template-columns:repeat(5,1fr);gap:var(--space-8)}
.os-scale li{border:var(--line-width) solid var(--line);border-radius:var(--radius-control);padding:var(--space-8) var(--space-12);background:var(--layer-2)}
.os-scale-cap{display:flex;justify-content:space-between;color:var(--text-muted);margin-top:var(--space-8)}
.os-disclosure{border:var(--line-width) solid var(--line);border-radius:var(--radius-panel);padding:var(--space-12)}
.os-disclosure summary{cursor:pointer;display:flex;gap:var(--space-8);align-items:center}
</style>"""
if os.path.exists(HEAD_PY):
    head = subprocess.run(['python3', '-I', HEAD_PY], capture_output=True, text=True, check=True).stdout
else:
    head = FALLBACK_HEAD

page = f'''<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="claude:viewport-fit-sides" content="cover">
<title>{SLUG} Ladder</title>
{head}
<style>
/* page-local: card grid, thumbnails, viewer overlay. Tokens only. */
button{{font:inherit;color:inherit;background:none;border:0;padding:0;cursor:pointer;text-align:left}}
.os-scale button{{display:block;width:100%}}
.os-scale button>*{{display:block}}
.os-scale button>.label{{color:inherit}}
.os-scale button>.caption{{margin-top:var(--space-4)}}
.os-scale button:focus-visible,.shot:focus-visible,.open:focus-visible,.vbar button:focus-visible{{outline:var(--ring-width) solid var(--accent);outline-offset:var(--ring-width)}}
.os-sec{{scroll-margin-top:var(--space-24)}}
.grid{{display:grid;grid-template-columns:repeat(auto-fill,minmax(min(100%,640px),1fr));gap:var(--space-16)}}
.card{{display:flex;flex-direction:column;gap:var(--space-12);min-width:0;padding:var(--space-16)}}
.cap{{display:flex;flex-direction:column;gap:var(--space-4);align-items:flex-start}}
.shot{{display:block;width:100%;border-radius:var(--radius-control);overflow:hidden;background:var(--layer-2);border:var(--line-width) solid var(--line);aspect-ratio:16/10}}
.shot img{{width:100%;height:100%;object-fit:cover;object-position:top;display:block}}
.open{{margin-top:var(--space-8);border-bottom:var(--line-width) solid var(--line-strong)}}
.sm .shot img{{filter:grayscale(1)}}
.os-disclosure .inner{{display:flex;flex-direction:column;gap:var(--space-32)}}
.old-tier{{display:flex;flex-direction:column;gap:var(--space-12)}}
.viewer{{position:fixed;inset:0;z-index:20;background:var(--page);display:flex;flex-direction:column}}
.viewer[hidden]{{display:none}}
.vbar{{display:flex;align-items:center;gap:var(--space-8);padding:calc(var(--space-8) + env(safe-area-inset-top,0px)) max(var(--space-16),env(safe-area-inset-right,0px)) var(--space-8) max(var(--space-16),env(safe-area-inset-left,0px));border-bottom:var(--line-width) solid var(--line);background:var(--layer-1)}}
.vbar .vt{{flex:1;min-width:0;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}}
.vbar button{{padding:var(--space-4) var(--space-12);border:var(--line-width) solid var(--line);border-radius:var(--radius-control);background:var(--layer-2)}}
.viewer iframe{{flex:1;width:100%;border:0;background:var(--page)}}
@media (max-width:599px){{.os-scale{{grid-template-columns:1fr}}.os-scale-cap{{flex-direction:column}}}}
</style>
</head>
<body class="body" data-mode="report">
<main class="os-container">
<article class="os-doc">
<div class="os-front">
<div class="os-masthead">
<p class="os-meta label">mild2wild · round {CUR[1:]} · {len(cur)} cards</p>
<h1 class="title">{SLUG} Ladder</h1>
</div>
<section class="os-answer" aria-label="The answer"><div>
<p class="lead">{len(cur)} variants, mild to wilder. Mild to bold stays inside the system; wild and wilder each break one named rule.</p>
</div></section>
<nav aria-label="Tiers"><ol class="os-scale" aria-label="Mild to wilder">{ladder}</ol>
<div class="os-scale-cap label"><span>system holds</span><span>allowed to break</span></div></nav>
<div class="os-cols os-cols--3">
<div class="os-sheet"><div class="label">Look</div><p class="body-sm">Click any card to open the full page here. Arrow keys step through cards, Esc closes.</p></div>
<div class="os-sheet"><div class="label">Pick</div><p class="body-sm">Reply with a card number, or two to combine.</p></div>
<div class="os-sheet"><div class="label">Next round</div><p class="body-sm"><code>ladder from #id</code> or <code>push all + N wilder</code>.</p></div>
</div>
</div>
<div class="os-evidence">
{rows(cur, CUR)}
{hist}
</div>
</article>
</main>
<div class="viewer" id="viewer" hidden role="dialog" aria-modal="true" aria-label="Card viewer">
<div class="vbar label"><button type="button" id="vprev" aria-label="Previous card">←</button><button type="button" id="vnext" aria-label="Next card">→</button><span class="vt" id="vt"></span><button type="button" id="vclose">Close</button></div>
<iframe id="vframe" title="Card full page"></iframe>
</div>
<script>
(function(){{
  var viewer=document.getElementById('viewer'),frame=document.getElementById('vframe'),vt=document.getElementById('vt');
  var list=[].slice.call(document.querySelectorAll('.shot')),idx=-1,last=null;
  function show(i){{
    if(i<0||i>=list.length)return; idx=i; var b=list[i];
    vt.textContent=b.dataset.label; viewer.hidden=false;
    fetch(b.dataset.src).then(function(r){{if(!r.ok)throw 0;return r.text();}})
      .then(function(t){{frame.srcdoc=t;}})
      .catch(function(){{frame.removeAttribute('srcdoc');frame.src=b.dataset.src;}});
    document.getElementById('vclose').focus();
  }}
  function hide(){{viewer.hidden=true;frame.removeAttribute('srcdoc');frame.removeAttribute('src');if(last)last.focus();}}
  document.addEventListener('click',function(e){{
    var b=e.target.closest('[data-src]');
    if(b){{last=b;var s=b.dataset.src;show(list.findIndex(function(x){{return x.dataset.src===s;}}));return;}}
    var j=e.target.closest('[data-jump]');
    if(j){{var el=document.getElementById(j.dataset.jump);if(el)el.scrollIntoView({{behavior:matchMedia('(prefers-reduced-motion: reduce)').matches?'auto':'smooth',block:'start'}});}}
  }});
  document.getElementById('vclose').onclick=hide;
  document.getElementById('vprev').onclick=function(){{show(idx-1);}};
  document.getElementById('vnext').onclick=function(){{show(idx+1);}};
  document.addEventListener('keydown',function(e){{
    if(viewer.hidden)return;
    if(e.key==='Escape')hide(); else if(e.key==='ArrowLeft')show(idx-1); else if(e.key==='ArrowRight')show(idx+1);
  }});
}})();
</script>
</body>
</html>'''
open(G + '/index.html', 'w').write(page)
print(len(page), len(cur), [r for r, _ in older])
