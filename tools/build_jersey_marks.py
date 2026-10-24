"""Original vector jersey graphics; no fonts or third-party graphics."""
from pathlib import Path
root = Path(__file__).resolve().parents[1] / 'assets' / 'characters'
segments = {
    'a': '30,0 90,0 100,10 90,20 30,20 20,10',
    'b': '94,24 104,14 104,80 94,90 84,80 84,34',
    'c': '94,98 104,108 104,174 94,164 84,154 84,108',
    'd': '30,158 90,158 100,168 90,178 30,178 20,168',
    'e': '16,98 26,108 26,154 16,164 6,174 6,108',
    'f': '16,24 26,34 26,80 16,90 6,80 6,14',
    'g': '30,79 90,79 100,89 90,99 30,99 20,89',
}
digits = {'0': 'abcdef', '7': 'abc', '2': 'abged', '3': 'abgcd'}
for number in ['07', '23']:
    parts = ['<svg xmlns="http://www.w3.org/2000/svg" width="256" height="416" viewBox="0 0 256 416">',
             '<g fill="none" stroke="#efe4c6" stroke-width="7" stroke-linecap="square" stroke-linejoin="miter">',
             '<path d="M23 61V25H41Q54 25 54 35Q54 45 41 45H23M40 45L57 61 M72 25V49Q72 62 86 62Q100 62 100 49V25 M143 27H123Q113 27 113 36Q113 44 126 44H132Q145 44 145 53Q145 62 134 62H113 M160 25V62 M188 25V62 M160 44H188"/>',
             '</g><path fill="#efe4c6" d="M24 83H231V86H24Z"/>']
    for index, digit in enumerate(number):
        parts.append(f'<g transform="translate({10+index*122},131)" fill="#efe4c6" stroke="#172e39" stroke-width="2">')
        for seg in digits[digit]:
            parts.append(f'<polygon points="{segments[seg]}"/>')
        parts.append('</g>')
    parts += ['<path fill="#efe4c6" d="M96 350L128 340 160 350 128 360Z"/>', '</svg>']
    (root / f'jersey_{number}.svg').write_text('\n'.join(parts), encoding='utf-8')
