          ttl     Generic Boot          sttl    boots first stage from IDE 0          pag               info    Bootstrap  for CPU09IDE          lib     unibug.h* UniFLEX Bootstrap Loader for CPU09IDE** Assumptions:* 'Boot' resides in to lower 65K blocks on the disk* boot from drive 0, first image** Special core locationscorcnt    equ     $13       lstmem    equ     $14       DATMAP    equ     $F40A      Map for $A000* Equatesffmap     equ     17         file map offset in fdnbhxfr     equ     10         transfer address offset in headerBHDSIZ    equ     24         binary file header sizePARTOFF   equ     $01f0      offset to partition table in disk block 0* System equates for single sector readSECLEN    equ     512           sector length** the UniFLEX kernel has some pointers at start of code** 5000   fdb  unidat            relic from "install"* 5002   fdb  parttbl (unidat2)* 5004   fdb  unikey            relic from "install"* 5006   fdb  unisrn* 5008   fdb  contabparttbl  equ  $5002             tell boot where to find pointer***************************************************************************************************  High Address            Low  Address       High              Low **  $f100                 $f101                Data 15...8       Data 7...0           (RW)*  $f102                 $f103              XXXX                 error/features       (R/W)*  $f104                 $f105              XXXX              sector count           (RW)*  $f106                 $f107              XXXX              LBA 0...7            (RW)*  $f108                 $f109              XXXX              LBA 8...15           (RW)*  $f10A                 $f10B              XXXX              LBA 16...23          (RW)*  $f10C                 $f10D              XXXX              LBA 24...27          (RW)*  $f10E                 $f10F              XXXX              status/command       (R/W)*  $f110                 $f111              DMA Addr 15...8   DMA Addr 7...0        (W) *  $f113                                    DMA Addr 19...16/DMAEN/DMARD/INTEN/CSEL (W)*  $f118                                    Status bits IRQ/IDEDMRQ/IDEINTR/IDEIORDY/IDEIO16  (R)**************************************************************************************************** Temporary storage* will be overwritten when kernel intializes          org     bootorg-32     in low memory, past memory tablesdirect    rmb     1         index in mapmapptr    rmb     2         fdnbkn    rmb     3entrys    rmb     2         entries in directoryxfradr    rmb     2         conadr    rmb     2         controller base addressdrvsel    rmb     2         drive/table select bits********************************************* Start of program, ********************************************          org bootorg* Lookup "Boot" in directory** on entry U holds the controller base address* D holds drive select info*uboot     lbra    uboot0     skip disk type bytes* filename for bootingbootn   fcb     $0d        fcc     'image: 'btname  fcc     'uniflex'extchar fcb 0                   extra character for name        fcb     0,0,0,0,0,0     14 in totalcrlf    fcb     $0d,$0a,0*uboot0  stu     conadr          save this info        std     drvsel          drive select*        ldx     #bootn     show bootname        jsr     [rpdata]*        ldy     #20000uboot02 jsr     [rinchk]    key pressed        bcs     uboot01        jsr    delay        leay    -1,y        bne     uboot02         bra     uboot1*uboot01 jsr     [rinch]             get character from keyboard        cmpa    #'0        blo     uboot1              invalid        cmpa    #'9        bhi     uboot1        sta     extchar             extend boot name*uboot1    ldx     #crlf          jsr     [rpdata]*          lda     $010A      check block $A000 mapped in          cmpa    #BLKHOL    black hole?          bne     uboot2              dec     corcnt     decrease number of pages available          ldx     lstmem     pick up last page pointer          lda     ,-x        get a page          stx     lstmem              sta     $010A      set up map          sta     DATMAP     map it in for us** here the actual boot process starts*uboot2    ldd     #1         root directory fdn no.          jsr    fdnblk     read in fdn          ldd     7,y        find size of directory          jsr    divby8              lsra              rorb              std     entrys     save entry countread1     jsr    rdblk      read data block          lbne    noboot     exit if errorlookup    leax    2,u        point to filespec          ldd     0,u        check for deleted entry          beq     nxtent     skip deleted files          ldy     #btname point to boot file name          ldb     #14        set name lengthcmpnam    lda     0,x+                cmpa    0,y+       is this boot file entry?          bne     nxtent     if not, skip to next          decb              bne     cmpnam              ldd     0,u        found it, get fdn          bra     load       go load uniflexnxtent    ldx     entrys              leax    -1,x       decrement count          stx     entrys     end of directory?          lbeq     noboot     error if so          leau    16,u       point to next entry          cmpu    #buffer+512 past current block?          bne     lookup     check entry if not          bra     read1      else, get another block* found it, Load Boot Imageload      jsr     fdnblk     read in uniflex fdn          jsr     rdblk      read 1st block of the file          bne     noboot     exit if error          ldd     bhxfr,u    get transfer address          std     xfradr     save it          leau    BHDSIZ,u   skip binary file headergetrc1    bsr     getchr     get record length in x          tfr     b,a                 bsr     getchr              cmpd    #0         terminator?          beq     done       start uniflex if so          tfr     d,x                 bsr     getchr     get load address in y          tfr     b,a                 bsr     getchr              tfr     d,y       getrc2    bsr     getchr     get a data byte          stb     0,y+       put in memory          leax    -1,x       decrement the count          bne     getrc2     loop if not end of record          bra     getrc1     else, get next record* Boot is loaded, begin executiondone      clr     drvsel     set for disk 0          ldy     #bootno    point to block 0 of disk  0          jsr     mread      read boot sector in map           bne     noboot     error!          ldu     parttbl     we use (unidat2) as pointer to store partition table          bsr     cpypart* check ready drive 1          ldb     #IDE_DSL   drive select bit          stb     drvsel          pshs    u          ldy     #bootno    point to block 0 of disk 1          jsr     mread      read boot sector in mapdon05     puls    u          bne     don02      could not read          bsr     cpypart*don02     jmp     [xfradr]   jump to transfer address* copy part table from boot sector into kernelcpypart   equ     *          ldy     #map+PARTOFF  buffer with bootsector          ldx     #8         8 wordsdon01     ldd     0,y++          std     0,u++          leax    -1,x          bne     don01           rts** artificial blockno of boot sector on disk*bootno    fcb     0,0,0      we need it for mread* Divide contents of D by 8divby8    lsra              rorb              lsra              rorb              lsra              rorb              rts     * Get single character from binary filegetchr    cmpu    #buffer+512 more data in buffer?          bne     getch2     skip if so          pshs    a,x,y               bsr     rdblk      else, read another block          puls    a,x,y               bne     nbootx     exit if errorgetch2    ldb     0,u+       get character, advance ptr          rts     * Uniflex file was not foundnbootx    puls    d          fix stacknoboot    swi                return to monitor ROM* Read fdn specified in Dfdnblk    pshs    d          save fdn number          addd    #15        convert to block number          bsr     divby8              std     fdnbkn+1          clr     fdnbkn          ldy     #fdnbkn          bsr    mread      read a block          puls    d          restore fdn number          bne     nbootx     exit if error          decb    calculate  buffer offset          andb    #$07                lda     #64                 mul     offset=(fdn&7)*64          addd    #map                tfr     d,y        fdn pointer in y          addd    #9         point to ffmap          std     mapptr     save map pointer          lda     #10        get direct block count          sta     direct     initialize indirect flag          rts     * Read a block from filerdblk     tst     direct     a direct block?          beq     chgind     change to indirect          dec     direct     dec. direct count          ldy     mapptr     get file map pointer          ldx     #buffer    setup buffer address          bsr     xread      read the sector          pshs    cc          sty     mapptr          puls    cc,pcchgind    ldy     mapptr     get file map pointer          bsr     mread      read block of indirects          bne     nbootx     exit if error          stu     mapptr     reset file map pointer          lda     #128       set new direct count          sta     direct              bra     rdblk      now read data block***************************************************** Read the specified map block (low level)****************************************************mread     ldx     #map       address of buffer for block***************************************************** LOW level drivers for IDE * in PIO mode hibyte is don't care**   X - Buffer Address*   Y - Block # Pointer****************************************************** Read a single sector (A,B = block no)xread     pshs     x           keep buffer address          ldu      conadr          bsr     setadr      setup DMA address*          clra          ldb      #IDE_LBA    drive 0, LBA mode          orb      drvsel      drive          std      ideadr3,u          ldd      idecmst,u          cmpb     #IDERDY+IDEDSC          bne      ider2       error, not there*          ldb      2,y         block bits 15...0          std      ideadr0,u     LBA 0...7          ldb      1,y           std      ideadr1,u     LBA 8...15          ldb      0,y          std      ideadr2,u     LBA 16...23          leay     3,y         bump pointer to next #          ldd      #1           sector count          std      idescnt,u*          ldb      #IDEDRD     data read          std      idecmst,u     set commandider1     lda      idestat,u           bita     #IDEINTR    interrupt raised?          beq      ider1          clr      dmaltc,u     prevent DMA          ldd      idecmst,u     ack interrupt signal          andb     #IDEERR     leav error bitider2     puls     u,pc         buffer now in u* convert address for  CPU09IDEsetadr    lda     sysram      get memory map value          tfr     a,b                 lsra    get        upper half          lsra              lsra              lsra              ora     #L_DREAD+L_DMAEN          sta     dmaltc,u    address 19...16, READ DEVICE, DMA ENABLE          lslb                get lower half          lslb          lslb          lslb          pshs    b           save it          tfr     x,d         get address          anda    #$0F        mask off upper 4 bits          ora     0,s+        replace with map bits          std     dmaadh,u          rts* delaydelay     lda     #$40      del2      deca              bne     del2                rts     ****************************************************          if      (*-uboot)>512           err     Bootstrap Overflow!          else              rzb     512-(*-uboot)          endif   * Buffersbuffer    rmb     512       map       rmb     512                 end     