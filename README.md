## skel2json

This Perl script will read the binary skeleton format used by Spine v3.1.08 and output a JSON file that can be read by Spine v3.5. I have no plans to extend this with support for other versions, and it's not exactly pretty. Improvements are welcome.

Several sections are not currently being decoded because I didn't run into them in any of the files that I needed to convert. I will add support for them if I get a skeleton file that uses them.

### Usage

    skel2json.pl <file1.skel file2.skel file3.skel ...>

The script will convert the given `.skel` files and write `.json` files with the same file name. The last extension will be replaced with `.json`; for example, `filename.skel` becomes `filename.json`, `filename.skel.bytes` becomes `filename.skel.json`, and so on.
