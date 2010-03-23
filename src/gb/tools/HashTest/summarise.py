#!/usr/bin/env python
# encoding: utf-8

# Proust in his first book wrote about, wrote about,
# *BONG* Start again...

import re
from table import Table

PREFIXES = {
    'n': -3,
    'μ': -2,
    'm': -1,
    '':  0,
    'k': 1,
    'M': 2,
    'G': 3,
    'T': 4,
    'P': 5,
    'E': 6,
    'Z': 7,
    'Y': 8,
}

PREFIXES_REV = ('n', 'μ', 'm', '', 'k', 'M', 'G', 'T', 'P', 'E', 'Z', 'Y')

def to_seconds(num, prefix):
    return float(num.replace(',','')) * 1000**PREFIXES[prefix]

def fmt_sec(sec):
    # Convert to nano-seconds
    v = sec * 1000000000.0
    prefixInd = 0
    while v > 2500.0:
        v /= 1000.0
        prefixInd += 1

    if v >= 1000.0:
        return ("%d,%06.2f %ss" % (
            int(v/1000.0),
            v-(int(v/1000.0)*1000.0),
            PREFIXES_REV[prefixInd])).decode('utf8')

    else:
        return ("%.2f %ss" % (v, PREFIXES_REV[prefixInd])).decode('utf8')

def parse_log(ins):
    hm_sig = None
    test_sig = None
    test_min_max = None
    test_mean_sd = None
    test_95_conf = None

    def bundle():
        return test_sig, hm_sig, {
            #'hm': hm_sig,
            #'sig': test_sig,
            'min': test_min_max[0],
            'max': test_min_max[1],
            'mean': test_mean_sd[0],
            'sd': test_mean_sd[1],
            '95%': test_95_conf,
        }
    
    for line in ins:
        #print ' ++', line
        line = line.strip()
        if line.startswith("! "):
            if test_sig is not None:
                yield bundle()
                test_sig = None
                
            hm_sig = line[2:]

        elif line.startswith("+ "):
            if test_sig is not None:
                yield bundle()
            
            test_sig = line[2:]

        elif line.startswith(": "):
            if line.startswith(": range = "):
                mi,mip,ma,map = re.search(
                    r"\[([\d.,]+) ([^s]*)s, ([\d.,]+) ([^s]*)s\]",
                    line).groups()
                test_min_max = to_seconds(mi,mip), to_seconds(ma,map)

            elif line.startswith(": μ = "):
                m,mp,s,sd = re.search(
                    r"μ = ([\d.,]+) ([^s]*)s, σ = ([\d.,]+) ([^s]*)s",
                    line).groups()
                test_mean_sd = to_seconds(m,mp), to_seconds(s,sd)

            elif line.startswith(": 95% CI = "):
                c,cp = re.search(
                    r"± ([\d.,]+) ([^s]*)s",
                    line).groups()
                test_95_conf = to_seconds(c,cp)

    if hm_sig is not None:
        yield bundle()


def shorten(s):
    bits = s.split("-")
    return "-".join([bits[0][:2]] + bits[1:])


def main(args):
    results = {}
    impls = set()
    for test,hm,stats in parse_log(open('HashTest.log', 'r')):
        if test not in results:
            results[test] = {}

        print '+ %s : %s' % (test, hm)
        
        results[test][hm] = stats

        if hm not in impls:
            impls.add(hm)

    out = open('HashTest-Summary.txt', 'w')

    print >>out, 'Summary of results'
    print >>out, ''

    impls.remove('builtin')
    impl_list = zip(['builtin'] + list(sorted(impls)),
                    ['bi'] + [shorten(n) for n in sorted(impls)])

    header = [u'Test']
    for _,short in impl_list:
        header += [u'%s μ' % short,
                   #u'σ',
                   u'95% ±']
    for _,short in impl_list[1:]:
        header += [short]

    table_data = [header]

    for test,data in ((k, results[k])
                      for k in sorted(results.iterkeys())):
        row = [test]
        for full,short in impl_list:
            print '- %s : %s' % (test, full)
            row += [fmt_sec(data[full]['mean']),
                    #fmt_sec(data[full]['sd']),
                    fmt_sec(data[full]['95%'])]

        baseline = data['builtin']['mean']

        for full,short in impl_list[1:]:
            frac = baseline/data[full]['mean']
            if frac < 1.0: frac = -(1.0/frac)
            row += ['%.2f x' % frac]

        table_data.append(row)

    print >>out, Table(table_data).create_table().encode('utf8')
    out.close()

    import os
    os.system('rst2html.py HashTest-Summary.txt HashTest-Summary.html')



if __name__ == '__main__' and not __file__.endswith('idle.pyw'):
    import sys
    sys.exit(main(sys.argv[1:]))
