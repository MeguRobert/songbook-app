# -*- coding: utf-8 -*-
"""Build the MusicXML the app actually has to survive.

Started from real Audiveris output (tools/audiveris_output/zsolt-090.width-800.xml
-- 6 measures, two staves, no <work-title>, which is why a photographed score
arrived with an empty Title box). Then adds the one shape that took the renderer
down on song 151: a measure whose notes all belong to a voice that is NOT the
melody.

The app renders the melody only -- the lowest-numbered voice of the top staff of
the first part -- so such a measure arrives with zero beats in it, and
`beamGroups.reduce` used to throw on that, which a release build draws as a
plain grey rectangle.
"""
import io
import os
import re

SRC = r"C:\Users\rober\source\repos\songbook-app\tools\audiveris_output\zsolt-090.width-800.xml"
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'score.musicxml')

x = io.open(SRC, encoding='utf-8').read()

measures = list(re.finditer(r'<measure\b[^>]*>.*?</measure>', x, re.S))
print(f'source: {len(measures)} measures')

# Find a measure with notes in the melody, and rewrite its voice so the melody
# has nothing there. The second measure, so the first still establishes a staff.
target = measures[1]
body = target.group(0)
voices = sorted(set(re.findall(r'<voice>(\d+)</voice>', body)))
print('voices in that measure:', voices)

# Push every note in this measure into a voice the melody filter will not pick.
rewritten = re.sub(r'<voice>\d+</voice>', '<voice>7</voice>', body)
assert rewritten != body, 'no <voice> elements to rewrite'
x = x[:target.start()] + rewritten + x[target.end():]

io.open(OUT, 'w', encoding='utf-8', newline='\n').write(x)
print('wrote', OUT, len(x), 'bytes')
print('work-title present:', '<work-title>' in x)
