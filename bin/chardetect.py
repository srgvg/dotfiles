#!/usr/bin/python3
import os
import chardet
for n in os.listdir('.'):
    print(chardet.detect(os.fsencode(n)), n)
