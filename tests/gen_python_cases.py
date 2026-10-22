"""Runs each case in real Python 3 and writes GDScript _expect_print lines with Python's output.

Usage: python tests/gen_python_cases.py out.gd   then paste the lines into _run_python_more() in
run_tests.gd. Add new cases to CASES; keep them free of robot functions and input().
"""
import io, json, subprocess, sys

CASES = [
    ("conditional expression", "x = 5\nprint('big' if x > 3 else 'small', [n if n % 2 else -n for n in range(4)])"),
    ("for/while else", "for n in [3, 5, 7]:\n    if n % 2 == 0:\n        print('even', n)\n        break\nelse:\n    print('no even')\ni = 0\nwhile i < 3:\n    i += 1\n    if i == 2:\n        break\nelse:\n    print('never')\nprint(i)"),
    ("chained and starred assignment", "a = b = [0]\nb.append(1)\nprint(a, a is b)\nfirst, *rest = [1, 2, 3]\n*init, last = 'abc'\nprint(first, rest, init, last)\nx, (y, z) = 1, (2, 3)\nprint(x + y + z)"),
    ("augmented bit operators", "x = 2\nx **= 3\nx |= 1\nx ^= 3\nx <<= 2\nx >>= 1\nx &= 7\nprint(x)"),
    ("defaults, *args, **kwargs", "def greet(name, greeting='안녕', *rest, **opts):\n    return f'{greeting}, {name}{len(rest)}{sorted(opts)}'\nprint(greet('철수'))\nprint(greet('영희', '반가워', 1, 2, mark='!'))\nprint(greet(greeting='hi', name='a'))\ndef add(*nums):\n    return sum(nums)\nprint(add(), add(1, 2, 3), add(*[4, 5]))\ndef show(**kw):\n    return kw\nprint(show(a=1, **{'b': 2}))"),
    ("default values are made once", "def push(x, box=[]):\n    box.append(x)\n    return box\npush(1)\nprint(push(2))"),
    ("type hints", "def f(x: int, y: float = 1.5) -> float:\n    return x * y\nn: int = 4\nprint(f(n))"),
    ("lines joined in brackets and after a backslash", "total = (1 +\n         2 +\n         3)\nitems = [\n    'a',\n    'b',\n]\ns = 'x' + \\\n    'y'\nprint(total, items, s)"),
    ("docstrings and triple-quoted strings", "def f():\n    \"\"\"두 줄\n    설명\"\"\"\n    return 1\ntext = \"\"\"a\nb\"\"\"\nprint(f(), text.split('\\n'), len(text))"),
    ("semicolons and one-line blocks", "a = 1; b = 2\nif a < b: print('lt'); print('both')\nfor i in range(2): print(i)\nwhile False: pass\nprint(a + b)"),
    ("raw strings and escapes", "print(r'a\\nb', len(r'\\t'), 'q\\'s', \"tab\\tend\")"),
    ("number literals", "print(0x1F, 0o17, 0b101, 1_000, 1e3, 2.5e-1)"),
    ("bit operators", "print(5 ^ 3, ~5, 1 << 3, 16 >> 2, 6 & 3, 6 | 3, {1, 2} ^ {2, 3})"),
    ("print sep and end", "print('a', 'b', sep='-', end='')\nprint('!')\nprint(1, 2, end=' ')\nprint(3)\nprint(*[1, 2, 3], sep=',')"),
    ("% formatting", "print('%d개 %s %.2f %5.1f|%-4s|%03d %x %%' % (3, 'a', 3.14159, 2.26, 'ab', 7, 255))\nprint('%s님' % '철수', '%r' % 'a', '%+d' % 5)"),
    ("str.format", "print('{}님 {}개'.format('a', 3), '{1}{0}'.format('x', 'y'), '{name:>4}|{0:.1%}'.format(0.25, name='b'), '{{}}'.format(), '{!r}'.format('q'))"),
    ("f-string format specs", "x = 7\nname = 'ab'\npi = 3.14159\nprint(f'{x:>3}|{x:<3}|{x:^5}|{x:03}|{name:*^6}|{pi:.3f}|{1234567:,}|{0.5:.0%}|{255:#x}|{5:b}|{-3:+d}|{x=}|{name!r}')\nprint(f'{12345.678:.2e}|{1.5:g}|{100000.0:g}|{1e6:g}|{0.000123:g}|{123456789:g}|{3.0}|{2:5.1f}|{-2.5:08.2f}|{1234.5:,.1f}')"),
    ("format()", "print(format(3.14159, '.1f'), format(42, '>5'), format('a', '^3') + '|', format(10, 'x'))"),
    ("more builtins", "print(any([0, 1]), all([]), list(map(abs, [-1, 2])), list(map(lambda a, b: a * b, [1, 2], [3, 4])), list(filter(None, [0, 3, ''])), list(filter(lambda n: n > 1, [1, 2, 3])))\nprint(list(reversed('abc')), divmod(-7, 2), pow(2, 10), pow(3, 4, 5), ord('A'), chr(44032), bin(5), hex(-255), oct(8), int('ff', 16), int('0b11', 0), bool(''), bool([0]), round(2.567, 2))"),
    ("isinstance and type", "class A:\n    pass\nclass B(A):\n    pass\nprint(isinstance(B(), A), isinstance(A(), B), isinstance(3, (str, int)), isinstance(True, int), type(3) == int, type('a'), type(A()) == A, type([]) is list, type(2.0))"),
    ("iter and next", "it = iter([1, 2])\nprint(next(it), next(it), next(it, 'end'))\nfor x in iter('ab'):\n    print(x)"),
    ("more string methods", "s = '  Hello World  '\nprint(s.strip().find('o'), s.rfind('o'), s.find('z'), '12'.isdigit(), 'ab'.isalpha(), '한글'.isalpha(), 'a1'.isalnum(), 'AB'.isupper(), 'ab'.islower(), ' '.isspace(), ''.isdigit())\nprint(s.lstrip() + '|', s.rstrip() + '|', 'hello world'.title(), 'hELLO'.capitalize(), '7'.zfill(3), '-7'.zfill(4), 'ab'.center(6, '*'), 'abc'.center(6, '*'), 'ab'.ljust(4) + '|', 'ab'.rjust(4), 'xxhixx'.strip('x'), 'aBc'.swapcase(), 'a  b\\tc'.split())"),
    ("list, dict and set methods", "x = [1, 2]\nx.extend((3, 4))\ny = x.copy()\nx.clear()\nx += 'ab'\nprint(x, y)\nx = [0, 1, 2, 3, 4]\nx[1:3] = ['a']\ndel x[::2]\nprint(x)\nd = {'a': 1}\nd.update({'b': 2})\nd.update([('c', 3)])\nprint(d.setdefault('a', 9), d.setdefault('z', 0), d)\ne = d.copy()\nd.clear()\nprint(d, len(e), d | {'q': 1})\ns = {1, 2, 3}\nprint(s.union([4]), s.intersection({2, 9}), s.difference([1]), s.symmetric_difference({3, 4}), {1}.issubset(s), s.issuperset({1, 2}), s.isdisjoint({7}), {1, 2} <= s, s > {1})"),
    ("+= changes the list itself", "a = [1]\nb = a\nb += [2]\nprint(a)"),
    ("from/as imports", "from math import sqrt, pi as PI\nimport math as m\nimport random as r\nfrom random import *\nprint(sqrt(16), round(PI, 2), m.floor(2.5), randint(1, 1), choice('a'), r.randint(2, 2))"),
    ("assert", "assert 1 + 1 == 2\ntry:\n    assert 2 < 1, '틀림'\nexcept AssertionError as e:\n    print('잡음', e)"),
    ("nested comprehensions", "print([a * b for a in [1, 2] for b in [3, 4]], [(i, j) for i in range(3) for j in range(i)], {k: v for k, v in [('a', 1)]}, [x for x in range(10) if x % 2 if x > 4], [x if x > 0 else 0 for x in [-1, 2]])"),
    ("for with nested targets", "for i, (a, b) in enumerate([(1, 2), (3, 4)], start=1):\n    print(i, a + b)\nprint(list(enumerate('ab', 1)), sum([1, 2], 10))"),
    ("del a variable", "x = 1\ndel x\ntry:\n    print(x)\nexcept NameError:\n    print('gone')"),
    ("keyword arguments to a class", "class P:\n    def __init__(self, x=0, y=0):\n        self.x = x\n        self.y = y\np = P(y=5)\nprint(p.x, p.y)"),
    ("unpacking into lists and tuples", "print([*'ab', *[1]], (*range(2),), [*{'k': 1}])"),
    ("slice assignment grows and shrinks", "x = [1, 2, 3]\nx[1:] = [9]\nprint(x)\nx[1:1] = [7, 8]\nprint(x)\nx[::2] = ['a', 'b']\nprint(x)"),
    ("float printing", "print(0.1 + 0.2, 1 / 3, 2 ** 0.5, 1e-5, 1e16, 1e15, 123456789.123, -0.5, 2.0, 1e22, 0.0001, 3.14e-10)"),
    ("math functions", "import math\nprint(math.gcd(12, 18), math.gcd(4, 6, 10), math.lcm(4, 6), math.factorial(5), math.isqrt(10), math.comb(5, 2), math.perm(5, 2), math.prod([1, 2, 3, 4]))\nprint(math.sin(0), math.cos(0), round(math.sin(math.pi / 2), 3), math.degrees(math.pi), math.radians(180), math.log(math.e), math.log10(1000), math.log2(8), math.log(8, 2), math.exp(0))\nprint(math.hypot(3, 4), math.dist((0, 0), (3, 4)), math.fabs(-2), math.trunc(-2.7), math.floor(-2.5), math.ceil(2.1), math.inf > 10 ** 9, math.e, math.tau, math.isclose(0.1 + 0.2, 0.3), math.atan2(1, 1) == math.pi / 4)"),
    ("random module", "import random\nx = [1, 2, 3, 4, 5]\nrandom.shuffle(x)\nprint(sorted(x), len(random.sample(x, 3)), len(set(random.sample(x, 5))), 1 <= random.uniform(1, 2) <= 2, random.randrange(10) < 10, random.randrange(2, 3), random.randrange(0, 10, 5) in [0, 5])\nrandom.seed(5)\na = random.random()\nrandom.seed(5)\nprint(a == random.random())"),
    ("collections.Counter", "from collections import Counter\nc = Counter('banana')\nprint(c, c['a'], c['z'], c.most_common(1), c.most_common(2))\nc.update(['a', 'z'])\nprint(c['a'], c['z'], c.total(), sorted(c.elements())[:3], len(c))\nprint(Counter([1, 1, 2]) + Counter([2, 3]), Counter('aab') - Counter('a'), dict(Counter('xyx')), Counter())"),
    ("collections.defaultdict", "from collections import defaultdict\nd = defaultdict(int)\nfor w in ['a', 'b', 'a']:\n    d[w] += 1\nprint(d, d['a'], dict(d))\ng = defaultdict(list)\ng['x'].append(1)\ng['x'].append(2)\nprint(g['x'], len(g), 'y' in g)"),
    ("collections.deque", "from collections import deque\nq = deque([1, 2, 3])\nq.append(4)\nq.appendleft(0)\nprint(q, q.popleft(), q.pop(), q, len(q), q[0], q[-1], 2 in q)\nq.rotate(1)\nprint(q)\nq.rotate(-1)\nq.extendleft([9, 8])\nprint(q, list(q))\nr = deque(maxlen=2)\nfor i in range(4):\n    r.append(i)\nprint(r)"),
    ("statistics", "import statistics\nprint(statistics.mean([1, 2, 3]), statistics.mean([1, 2]), statistics.mean([1.5, 2.5]), statistics.median([3, 1, 2]), statistics.median([1, 2, 3, 4]), statistics.mode(['a', 'b', 'b', 'a', 'b']), statistics.median([5, 1]))"),
    ("itertools", "import itertools\nprint(list(itertools.permutations([1, 2, 3])))\nprint(list(itertools.permutations('abc', 2)), list(itertools.combinations([1, 2, 3, 4], 2)))\nprint(list(itertools.product('ab', [0, 1])), list(itertools.product([0, 1], repeat=2)), list(itertools.chain([1], (2, 3))), list(itertools.accumulate([1, 2, 3, 4])))\nit = itertools.combinations('xyz', 2)\nprint(next(it), min(itertools.permutations([3, 1, 2])))"),
    ("string and time", "import string, time\ntime.sleep(0)\nprint(string.ascii_lowercase[:5], string.ascii_uppercase[-3:], string.digits, len(string.ascii_letters), '!' in string.punctuation)"),
    ("module names are free before import", "time = 3\nstring = 'abc'\nprint(time + 1, string)"),
]

out = []
for label, src in CASES:
    r = subprocess.run([sys.executable, '-I', '-X', 'utf8', '-c', src], capture_output=True, text=True, encoding='utf-8',
                       env={'PYTHONIOENCODING': 'utf-8', 'SYSTEMROOT': __import__('os').environ.get('SYSTEMROOT', '')})
    if r.returncode != 0:
        print('PYTHON FAILED', label, r.stderr, file=sys.stderr)
        sys.exit(1)
    expected = '|'.join(r.stdout.rstrip('\n').split('\n'))
    out.append('\tawait _expect_print(%s, %s, %s)' % (json.dumps(src, ensure_ascii=False), json.dumps(expected, ensure_ascii=False), json.dumps(label, ensure_ascii=False)))
io.open(sys.argv[1], 'w', encoding='utf-8', newline='\n').write('\n'.join(out) + '\n')
print(len(out), 'cases')
