# UPX

## Getting Start

在 Ubuntu 18.04.2 上可以用 apt 安裝

```
$ sudo apt install upx-ucl
```

因為還要修改所以自己 build 

```bash
$ sudo apt install ucl
$ git clone https://github.com/upx/upx.git
$ cd upx
$ git submodule update --init --recursive
$ make all
```

看 ucl 的 source 要用 apt source 下載（Ubuntu 的 package 可能有 patch）

```bash
$ apt source ucl
```

clone build src/stub 需要的 tool

```bash
$ git clone https://github.com/upx/upx-stubtools.git
```

目錄樹像這樣

```
.
├── test
│   ├── hello
│   └── yara
├── ucl
├── upx
└── upx-stubtools
```

* hello 下是用來測試 UPX 的 sample code
* yara 下放網路上搜尋的 rules <sup>[13] [14]</sup>


## Write-up

UPX <sup>[1]</sup> 加殼的原理簡單講就是壓縮 <sup>[2]</sup>，source 分成兩部份：

* 將 binary 加殼/脫殼的程式 <sup>[3] [4]</sup> 
* 加殼的 binary 在執行期間解壓縮到記憶體上執行原來 binary 的 loader

### 刪除 UPX 加殼的 binary 特徵

base on UPX 3.95 修改的 log

```
* 14bceaf8 (HEAD -> _feature_rebuild_loader_for_amd64_linux, origin/_feature_rebuild_loader_for_amd64_linux) feat: update amd64-linux.shlib-init.h
* fedee1c9 feat: update amd64-linux.kernel.vmlinux.h
* 69a321ca feat: update amd64-linux.elf-fold.h
* 1294d207 feat: update amd64-linux.elf-entry.h
* 6001a1bb feat: ignore checks in xstrip.py
* 99c6cc7a fix: fix the error "operand type mismatch for `pop'"
* 46a47de3 fix: fix the error "file is too big"
* 586da71b feat: add x86_64-linux-gnu toolcahin for amd64-linux
* 5a66d7c1 (origin/_feature_modify_binary_characteristic, _feature_modify_binary_characteristic) feat: modify the binary characteristic of UPX
* 7a3637ff (tag: v3.95, origin/master, origin/HEAD, master) Update NEWS.
```

看 Android SO（動代連結庫）UPX 加固指南 <sup>[7]</sup> 或類似的文章多少都有 UPX 加殼後的程式有那些特徵，用 ```strings BINARY | grep -i KEYWORD``` 就能找到

* UPX
* UPX!
* PROC_EXEC|PROT_WRITE failed
* This file is packed with the UPX executable packer http://upx.sf.net 

可以替換字串再重新編譯來解決

先在 3.95 版開一個 _feature_modify_binary_characteristic 的 branch 做修改

* src/conf.h 的 UPX_MAGIC_LE32
* src/packer.cpp 的 getIdentstr

一直到改到這幾個

* src/stub/src/include/linux.h 的 UPX_MAGIC_LE32
* src/stub/src/amd64-linux.elf-entry.S 的 PROC_EXEC|PROT_WRITE failed
* src/stub/src/amd64-linux.shlib-init.S 的 PROC_EXEC|PROT_WRITE failed

無論怎麼修改這些字串都還能用 string grep 出來，這時候發現有些字串已經被放進 dec 表示的 binary array，這些 array 都是 loader 的一部分，用 ```ag '80, 82, 79, 84, 95'``` 來搜 PROC_ 的 keyword

```
src/stub/amd64-linux.elf-entry.h
409:/* 0x1720 */  95, 69, 88, 69, 67,124, 80, 82, 79, 84, 95, 87, 82, 73, 84, 69,

src/stub/amd64-linux.shlib-init.h
409:/* 0x1720 */   0,  0,  0, 80, 82, 79, 84, 95, 69, 88, 69, 67,124, 80, 82, 79,
```

可以發現 amd64-linux 下至少有這兩個檔案含有 keyword。因為 array 有換行的問題，amd64-linux.elf-entry.h 的 408 行也有 PROC_EXEC|PROT_WRITE failed 字串的一部分，用 ag 過濾需要慢慢縮小範圍確認，然後再修改

另一個就是用 ```ag '85, 80, 88'``` 找 UPX! 這個字串

```
src/stub/amd64-linux.elf-fold.h
83:/* 0x02c0 */  85, 80, 88, 33,117, 17, 72,131,125,  0,  0, 15,132,181,  0,  0,
```

先改完 UPX! 覺得手工改這些 binary array 的 keyword 容易產生問題：

1. 搜尋的 keyword 不夠明顯會很多（換個角度來看，這也是改這些的目標）
2. 要確認改完的正確性需要反組譯（特別是符合問題 1 的時候）

需要先理解這些 binary array 怎麼做出來的，**PROC_EXEC|PROT_WRITE failed 先放著不改了**，把目前修改的先 commit（5a66d7c1）

### Generate src/stub 下的 headers

src/stub 下有 binary array 的 headers 不會在 compile 過程中自動產生出來，代表放進各平台 binary 的 loader 都固定的，但 src/stub 下有一些 assembly、c 的 sources 和 Makefile，之前改字串也在

* src/stub/src/amd64-linux.elf-entry.S
* src/stub/src/amd64-linux.shlib-init.S

發現 PROC_EXEC|PROT_WRITE failed，看來是可以重新編譯出來，再開一個 _feature_rebuild_loader_for_amd64_linux 的 branch 來 generate headers

先看 src/stub/Makefile

```makefile
# /***********************************************************************
# // amd64-linux.elf
# ************************************************************************/

amd64-linux.elf%.h : tc_list = amd64-linux.elf default
amd64-linux.elf%.h : tc_bfdname = elf64-x86-64

tc.amd64-linux.elf.gcc  = amd64-linux-gcc-3.4.4 -fPIC -m64 -nostdinc -MMD -MT $@
tc.amd64-linux.elf.gcc += -fno-exceptions -fno-asynchronous-unwind-tables
tc.amd64-linux.elf.gcc += -Wall -W -Wcast-align -Wcast-qual -Wstrict-prototypes -Wwrite-strings -Werror

amd64-linux.elf-entry.h: $(srcdir)/src/$$T.S
        $(call tc,gcc) -c -x assembler-with-cpp $< -o tmp/$T.bin
        $(call tc,f-embed_objinfo,tmp/$T.bin)
        $(call tc,bin2h) tmp/$T.bin $@

amd64-linux.elf-fold.h : tmp/$$T.o tmp/amd64-linux.elf-main.o $(srcdir)/src/$$T.lds
#       # FIXME: multiarch-ld-2.18 creates a huge file here, so use 2.17
#       ####$(call tc,ld) --strip-all -T $(srcdir)/src/$T.lds -Map tmp/$T.map $(filter %.o,$^) -o tmp/$T.bin
        multiarch-ld-2.17 --strip-all -T $(srcdir)/src/$T.lds -Map tmp/$T.map $(filter %.o,$^) -o tmp/$T.bin
        $(call tc,f-objstrip,tmp/$T.bin)
        $(call tc,sstrip) tmp/$T.bin
        $(call tc,bin2h) tmp/$T.bin $@

tmp/amd64-linux.elf-fold.o : $(srcdir)/src/$$T.S
        $(call tc,gcc) -c $< -o $@
        $(call tc,f-objstrip,$@)

tmp/amd64-linux.elf-main.o : $(srcdir)/src/$$T.c
        $(call tc,gcc) -c -Os $< -o $@
        $(call tc,f-objstrip,$@)
```

先嘗試 build 之前改 UPX! 的 src/stub/amd64-linux.elf-fold.h

我想盡可能跟開發者用的平台和工具保持一至，在網路上搜尋 default 的 toolchain 很久，但找不到 multiarch- 的相關資訊

以 multiarch-ld-2.17 來推測，如果開發者用是 binutils 是 2.17 版的話有幾種可能：

1. toolchain 是自己 build 的
2. 開發者用的平台非常舊了（Ubuntu 18.04.2 的 binutils 是 2.30 版）

總之先換 toolchain 編譯看看

網路上換的方法 <sup>[8]</sup> 都差不多，對於要維護其他平台或後續的版本太費工了，我換別的方式改 Makefile（586da71b）

```
$ make amd64-linux.elf-fold.h
```

build 下去馬上就碰到錯誤

```
tmp/amd64-linux.elf-main.o: In function `unpackExtent':
amd64-linux.elf-main.c:(.text+0x14c): undefined reference to `__stack_chk_fail'
tmp/amd64-linux.elf-main.o: In function `do_xmap':
amd64-linux.elf-main.c:(.text+0x433): undefined reference to `__stack_chk_fail'
tmp/amd64-linux.elf-main.o: In function `upx_main':
amd64-linux.elf-main.c:(.text+0x66a): undefined reference to `__stack_chk_fail'
Makefile:365: recipe for target 'amd64-linux.elf-fold.h' failed
```

這個錯誤很明顯是 canary 的問題，Ubuntu gcc 預設有開 ```-fstack-protector```，所以加上 ```-fno-stack-protector``` 關掉

接著 build 下去又碰到錯誤 ```ERROR: file is too big```，src/stub/scripts/bin2sh.py 裡會檢查 size 不能大於 128 * 1024 bytes

看一下 build 出來 src/stub/tmp/amd64-linux.elf-fold.bin 的 size

```bash
$ ls -lh amd64-linux.elf-fold.bin 
-rw-r--r-- 1 user user 1.1M Jul 26 12:49 amd64-linux.elf-fold.bin
```

想起 Makefile 的 FIXME，又看了 build 出來的 object size 

```bash
$ ls -lh *.o
-rw-r--r-- 1 user user 2.7K Jul 26 12:49 amd64-linux.elf-fold.o
-rw-r--r-- 1 user user 3.0K Jul 26 12:49 amd64-linux.elf-main.o
```

2.7K 和 3K link 出來的 binary 變 1.1M 不太合理，上網找資料看到 ld linker script producing huge binary <sup>[9]</sup> 這篇的回覆

> By default ld page-aligns input sections. Since your kernel enforces superpages (pages of 2MB = 0x200000 bytes) your .text section gets aligned at offset 0x200000. It seems like a bug in ld as it should use offset 0x0000000 instead (see EDIT below for a possible explanation)
> 
> To prevent this alignment which creates a bigger file, you can use the --nmagic flag to ld to prevent it from page-aligning your .text section although it has side effects (it also disables linking against shared libraries). Be careful though to align other sections (.data, .rodata,...) to 2M pages because they can't live in the same page as .text since all these sections require different access bits.
> 
> EDIT: thinking about it, we all expect accesses to virtual address 0x00000000 to generate an exception (segfault). To do so, I see two possibilities: either the kernel maps a page with no access rights (r/w/x) or (more likely) it simply doesn't map anything (no page mapped => segfault) and the linker must know that somehow... that could explain why ld skips the first page which is at address zero. This is TBC.

雖然我用 ```--nmagic``` 沒效果，但依這個方向找參考資料，蠻多解法都用 ```-z max-page-size=0x1000``` 將 page size 限制在 4K（包括一開始看到那篇也有人回覆這種方法）

```bash
$ getconf PAGE_SIZE
4096
```

看一下系統的 page size 也是 4K，加上參數重新編譯 generate 出 amd64-linux.elf-fold.h 算暫時解決掉問題（46a47de3），之後還要想辦法確認這篇文章的正確性

接著 ```make amd64-linux.elf-entry.h``` 也是馬上出現錯誤訊息

```
src/amd64-linux.elf-entry.S: Assembler messages:
src/amd64-linux.elf-entry.S:288: Error: operand type mismatch for `pop'
```

這個錯誤是因為 x86_64 不能 pop $ecx，也沒讀完 source 不知道開發者是不是真的只要 $ecx 先改成 $rax，之後再確認 source（99c6cc7a）

再 build 又出現錯誤

```python
Traceback (most recent call last):
  File "./../../src/stub/scripts/xstrip.py", line 222, in <module>
    sys.exit(main(sys.argv))
  File "./../../src/stub/scripts/xstrip.py", line 216, in main
    do_file(arg)
  File "./../../src/stub/scripts/xstrip.py", line 158, in do_file
    assert e_shstrndx + 3 == e_shnum
AssertionError
```

這個問題沒什麼頭緒也找不到相關資料，照著 Makefile 一行行指令做，用 readelf 觀察 Number of section headers 和 Section header string table index 始終都差 1，寫了一個 Hello, World 的 sample 來觀察也是一樣，不懂為什麼開發者要這樣判斷。去翻 git log 在 src/stub/scripts/xstrip.py 這個檔案第二次 commit 就加入了，除了一行 Improve xstrip.py 的描述也沒找到其他說明，只好先用目前實驗的結果修改成 ```assert e_shstrndx + 1 == e_shnum```

重新編譯 xstrip.py 又出現錯誤

```python
Traceback (most recent call last):
  File "./../../src/stub/scripts/xstrip.py", line 222, in <module>
    sys.exit(main(sys.argv))
  File "./../../src/stub/scripts/xstrip.py", line 216, in main
    do_file(arg)
  File "./../../src/stub/scripts/xstrip.py", line 181, in do_file
    assert pos == len(odata), ("unexpected strip_with_dump", pos, len(odata))
AssertionError: ('unexpected strip_with_dump', 6728, 6107)
```

直接翻 git log 看最早是沒檢查的，這幾年開發者也是開開關關的，source 也有註解

```c
# Other compilers can intermix the contents of .rela sections
# with PROGBITS sections.  This happens on powerpc64le and arm64.
# The general solution probably requires a C++ program
# that combines "objcopy -R", "objdump -htr", and xstrip.
```

我也不懂為什麼這邊開發者要這樣判斷而且我在 x86_64 上，所以也先改成 pass 重新編譯算暫時解決掉問題（6001a1bb）

改完這些後 amd64-linux 相關的 headers 都 build 的很順利

```bash
$ make amd64-linux.kernel.vmlinux.h
$ make amd64-linux.shlib-init.h
```


## References

1. [UPX](https://upx.github.io/)
2. [UPX 加殼原理](https://blog.csdn.net/zacklin/article/details/7419001)
3. [UPX 入門學習筆記](https://www.twblogs.net/a/5c4c9656bd9eee6e7d821716)
4. [UPX 原始碼分析——加殼篇](https://www.itread01.com/content/1548839730.html)
5. [Android so UPX加殼](https://www.itread01.com/p/61272.html)
6. [Using UPX as a Security Packer](https://dl.packetstormsecurity.net/papers/general/Using_UPX_as_a_security_packer.pdf)
7. [Android SO（動代連結庫）UPX 加固指南](https://www.cnblogs.com/fishou/p/4202061.html)
8. [UPX /src/stub/Makefile 編譯 armv7](https://www.jianshu.com/p/87dac9754e9b)
9. [ld linker script producing huge binary](https://stackoverflow.com/questions/15400910/ld-linker-script-producing-huge-binary)
10. [linux 下 UPX 脫殼筆記](https://bbs.pediy.com/thread-79061.htm)
11. [Manual unpacking UPX on 64-bit Linux](https://asciinema.org/a/bei8od5pxnihypp0j91o4ukj0)
12. [手脱定制版的 Android SO UPX 殼](https://bbs.pediy.com/thread-221997.htm)
13. [godaddy/yara-rules](https://github.com/godaddy/yara-rules/)
    * [packers/upx.yara](https://github.com/godaddy/yara-rules/blob/master/packers/upx.yara)
14. [SpiderLabs/yara-ruby](https://github.com/SpiderLabs/yara-ruby/)
    * [yara-ruby/spec/samples/upx.yara](https://github.com/SpiderLabs/yara-ruby/blob/master/spec/samples/upx.yara)
