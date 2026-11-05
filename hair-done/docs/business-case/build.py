# Builds hairdone-business-case.html: page.html with model.js dropped in where it says /*MODEL*/.
# Usage: python3 build.py  (from this folder, or pass the folder as the first argument)
import os, sys
S = sys.argv[1] if len(sys.argv) > 1 else os.path.dirname(os.path.abspath(__file__))
page = open(S + '/page.html').read()
model = open(S + '/model.js').read().replace('if (typeof module !== "undefined") module.exports = MODEL;\n', '')
open(S + '/hairdone-business-case.html', 'w').write(page.replace('/*MODEL*/', model))
