do; s entry0
db -$$ @@= `db~[0]`

?e ============ UPX unpacker ============

e search.from=entry0; e search.to=entry0+0x1000;
f p @@= `/a call rbp~:1[0]`
dcu p; f base @ `dr rbp`
dcu p+$l @@= p

e search.from=base; e search.to=base+0x1000;
f p @@= `/x 41ff27~:1[0]`
dcu p; s `dr rsp`; f OEP @@= `pxq 8~:0[1]`; dcu OEP; s OEP

pd 1

