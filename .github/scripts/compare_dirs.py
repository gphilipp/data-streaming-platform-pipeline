import filecmp
import shutil
import os
from pathlib import Path
from git import Repo

def copytree(src, dst, symlinks=False, ignore=None):
    for item in os.listdir(src):
        s = os.path.join(src, item)
        d = os.path.join(dst, item)
        if os.path.isdir(s):
            if item != 'specific':
                shutil.copytree(s, d, symlinks, ignore)
        else:
            shutil.copy2(s, d)

def main():
    # directories to compare
    dir1 = Path('./directory1')
    dir2 = Path('./directory2')

    if not filecmp.dircmp(dir1, dir2).left_only:
        print("Directories are identical. No action needed.")
        return

    # clear directory2 content except 'specific'
    for item in os.listdir(dir2):
        s = os.path.join(dir2, item)
        if item != 'specific' and os.path.exists(s):
            if os.path.isdir(s):
                shutil.rmtree(s)
            else:
                os.remove(s)

    # copy directory1 content to directory2 except 'specific'
    copytree(dir1, dir2)

if __name__ == '__main__':
    main()

