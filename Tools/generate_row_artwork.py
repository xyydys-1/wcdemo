"""Rebuild original bundled row tiles. Optional authoring tool; requires Pillow.
The app uses these PNG images directly, not an SF Symbols label in a list row.
"""
from pathlib import Path
from PIL import Image, ImageDraw
import math

ROOT = Path(__file__).resolve().parents[1]
SCALE = 6
COLORS = {
    'friends': '#28BD66', 'group': '#22BC71', 'tag': '#FAA233',
    'service': '#23B76A', 'wave': '#327CE2', 'seal': '#8063D8',
    'profile': '#2A98E8', 'privacy': '#6581BC', 'chat': '#26BA68',
    'video': '#F49B35', 'camera': '#378DEF', 'broadcast': '#EF646A',
    'scan': '#358AE8', 'shake': '#4485DF', 'news': '#E7A439',
    'search': '#EE645B', 'location': '#428BE7', 'apps': '#8462D4',
    'collection': '#E7A03F', 'photo': '#3C9AD9', 'card': '#DC9948',
    'smile': '#E8AE37', 'settings': '#858C97', 'mute': '#8490B2',
    'pin': '#F3A543', 'bell': '#DAAB44', 'trash': '#E96564',
    'layout': '#6091DD', 'attachment': '#8A92A0',
}

def tile(name, color):
    im = Image.new('RGBA', (64*SCALE, 64*SCALE))
    d = ImageDraw.Draw(im)
    def box(b): return tuple(round(v*SCALE) for v in b)
    def rect(b, radius=0, fill='white', outline=None, width=3):
        d.rounded_rectangle(box(b), radius=radius*SCALE, fill=fill, outline=outline, width=width*SCALE)
    def ellipse(b, fill='white', outline=None, width=3):
        d.ellipse(box(b), fill=fill, outline=outline, width=width*SCALE)
    def line(points, fill='white', width=3):
        pts=[(round(x*SCALE),round(y*SCALE)) for x,y in points]
        d.line(pts, fill=fill, width=width*SCALE, joint='curve')
        r=width*SCALE/2
        for x,y in [pts[0],pts[-1]]: d.ellipse((x-r,y-r,x+r,y+r),fill=fill)
    def polygon(points, fill='white'):
        d.polygon([(int(x*SCALE),int(y*SCALE)) for x,y in points], fill=fill)
    def arc(b, start, end, fill='white', width=3):
        d.arc(box(b), start, end, fill=fill, width=width*SCALE)
    def person(cx, cy, size=1):
        r=5*size
        ellipse((cx-r,cy-r,cx+r,cy+r))
        rect((cx-9*size,cy+7*size,cx+9*size,cy+20*size),6*size)
    rect((0,0,64,64),15,fill=color)
    if name in ('friends','profile'):
        person(29,23,1.05)
        if name=='friends':
            ellipse((39,34,56,51),fill=color)
            line([(42,43),(53,43)],width=2)
            line([(47.5,37.5),(47.5,48.5)],width=2)
    elif name=='group':
        person(18,24,.72);person(46,24,.72);person(32,21,1.02)
    elif name=='tag':
        polygon([(16,29),(29,16),(46,16),(48,34),(33,49)])
        ellipse((36,22,41,27),fill=color)
    elif name in ('service','collection'):
        rect((15,25,49,49),5)
        if name=='service':
            arc((24,14,40,36),180,360,width=3)
        else:
            line([(15,29),(32,35),(49,29)],fill=color,width=2)
            line([(32,35),(32,48)],fill=color,width=2)
            rect((13,19,51,27),3)
    elif name=='wave':
        for y in (22,32,42):
            pts=[(x,y+3*math.sin((x-13)*math.pi/16)) for x in range(13,52)]
            line(pts,width=3)
    elif name=='seal':
        points=[]
        for k in range(20):
            a=k*math.pi/10-math.pi/2;r=20 if k%2==0 else 16
            points.append((32+math.cos(a)*r,32+math.sin(a)*r))
        polygon(points);ellipse((24,24,40,40),fill=color)
    elif name=='privacy':
        polygon([(16,19),(32,13),(48,19),(46,39),(40,46),(32,52),(24,46),(18,39)])
        line([(24,31),(30,37),(41,25)],fill=color,width=3)
    elif name=='chat':
        rect((13,16,51,44),10);polygon([(21,39),(20,51),(34,42)])
        for x in (23,32,41):ellipse((x-2,28,x+2,32),fill=color)
    elif name in ('video','broadcast'):
        rect((12,21,39,44),6);polygon([(43,27),(53,21),(53,44),(43,38)])
        if name=='broadcast':
            ellipse((17,13,22,18));arc((15,10,30,25),230,340,width=2)
    elif name=='camera':
        rect((13,22,51,46),5);rect((24,16,39,25),3)
        ellipse((24,25,41,42),fill=color);ellipse((28,29,37,38))
    elif name=='scan':
        for pts in [[(14,25),(14,14),(25,14)],[(39,14),(50,14),(50,25)],[(14,39),(14,50),(25,50)],[(39,50),(50,50),(50,39)]]:line(pts,width=3)
        rect((24,24,30,30),1);rect((35,24,41,30),1);rect((24,35,30,41),1)
        line([(36,36),(41,36),(41,41)],width=2)
    elif name=='shake':
        rect((24,16,40,48),4,fill=None,outline='white',width=3)
        line([(30,42),(34,42)],width=2)
        arc((12,21,25,43),120,240);arc((39,21,52,43),300,60)
    elif name=='news':
        rect((16,14,48,50),4)
        rect((21,21,30,30),1,fill=color)
        for y in (23,28):line([(35,y),(42,y)],fill=color,width=2)
        for y in (36,43):line([(22,y),(42,y)],fill=color,width=2)
    elif name=='search':
        ellipse((16,14,41,39),fill=None,outline='white',width=4)
        line([(38,36),(49,48)],width=5)
    elif name=='location':
        ellipse((17,11,47,41));polygon([(18,31),(32,53),(46,31)])
        ellipse((26,21,38,33),fill=color)
    elif name in ('apps','layout'):
        if name=='apps':
            for x in (16,36):
                for y in (16,36):rect((x,y,x+13,y+13),4)
        else:
            for y in (19,31,43):
                rect((14,y,21,y+5),1);line([(28,y+2.5),(50,y+2.5)],width=3)
    elif name=='photo':
        rect((12,16,52,49),5,fill=None,outline='white',width=3)
        ellipse((36,23,43,30));polygon([(15,44),(26,30),(34,38),(41,33),(49,44)])
    elif name=='card':
        rect((13,20,51,46),5)
        rect((13,27,51,32),0,fill=color);rect((19,38,31,40),1,fill=color)
    elif name=='smile':
        ellipse((13,13,51,51));ellipse((23,24,27,29),fill=color);ellipse((37,24,41,29),fill=color)
        arc((23,27,41,44),5,175,fill=color,width=3)
    elif name=='settings':
        points=[]
        for k in range(48):
            r=[17,17,21,21,17,17][k%6];a=k*math.pi/24
            points.append((32+r*math.cos(a),32+r*math.sin(a)))
        polygon(points);ellipse((23,23,41,41),fill=color);ellipse((29,29,35,35))
    elif name in ('bell','mute'):
        ellipse((28,12,36,19));ellipse((21,16,43,37));rect((21,27,43,43),3)
        polygon([(21,33),(16,45),(48,45),(43,33)]);ellipse((28,46,36,51))
        if name=='mute':
            line([(14,14),(50,50)],fill=color,width=7)
            line([(14,14),(50,50)],width=3)
    elif name=='pin':
        polygon([(21,16),(43,16),(39,22),(39,32),(47,38),(17,38),(25,32),(25,22)])
        line([(32,38),(32,52)],width=3)
    elif name=='trash':
        rect((20,24,44,50),4,fill=None,outline='white',width=3)
        line([(16,21),(48,21)],width=3);rect((26,14,38,21),3,fill=None,outline='white',width=3)
        for x in (28,36):line([(x,29),(x,43)],width=2)
    elif name=='attachment':
        # Staggered cards with an attachment cross.
        rect((16,13,42,42),5,fill=None,outline='white',width=3)
        rect((23,21,51,50),5,fill=color,outline='white',width=3)
        line([(31,35),(43,35)],width=3);line([(37,29),(37,41)],width=3)
    return im.resize((96,96),Image.Resampling.LANCZOS)

if __name__ == '__main__':
    for name,color in COLORS.items():
        tile(name,color).save(ROOT/'Resources'/f'row_{name}.png',optimize=True)
    print(f'Wrote {len(COLORS)} original row tiles')
