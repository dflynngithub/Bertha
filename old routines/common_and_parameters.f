GLOBAL
      COMMON/COEF/C
      COMMON/DENS/DENC,DENO,DENT
      COMMON/EIGN/EIGEN(MDM)
      COMMON/ENRG/ETOT,ENUC,EONE,ECLG,ECLQ,EBRG,EBRQ,EHNC,EHKN,EGDR,
     &            EGXC,EQDR,EQXC,EBDR,EBXC,EMDR,EMXC,EUEH
      COMMON/FILL/NCNF(MCT,MKP,MKP+1),NLVL(MCT,MKP),IFILL(MCT)
      COMMON/FLNM/MOLCL,WFNFL,OUTFL
      COMMON/GEOM/SHAPE
      COMMON/MDLV/ELMNT
      COMMON/MTRX/OVAP,HNUC,HKIN,VUEH,GDIR,GXCH,QDIR,QXCH,BDIR,BXCH,FOCK
      COMMON/OCPD/IOCPN(MDM),IOCCM0
      COMMON/PRMS/CV,HMLTN,ITREE,IMOL,INEW,ILEV,ISWZ,IEQS,IERC,IPAR,ICOR
      COMMON/SHLL/ACFF,BCFF,FOPN,ICLS(500),IOPN(6),NCLS,NOPN,NOELEC
      COMMON/SPEC/EXPSET(MBS,MKP,MCT),COORD(3,MCT),ZNUC(MCT),AMASS(MCT),
     &            CNUC(MCT),PNUC,LARGE(MCT,MKP,MKP+1),NFUNCT(MKP,MCT),
     &            KVALS(MKP,MCT),IZNUC(MCT),IQNUC(MCT),LMAX(MCT),
     &            NKAP(MCT),NCNT,NDIM,NSHIFT,NOCC,NVRT

ATOMIC
      COMMON/ATMB/B11(MBD,MBD),B21(MBD,MBD),B12(MBD,MBD),B22(MBD,MBD)
      COMMON/ATMC/G11(MBD,MBD),G21(MBD,MBD),G12(MBD,MBD),G22(MBD,MBD)
      COMMON/ATMD/DLL1(MB2),DSL1(MB2),DSS1(MB2),DLS1(MB2),
     &            DLL2(MB2),DSL2(MB2),DSS2(MB2),DLS2(MB2)
      COMMON/BIJS/EIJ(-MAB:MAB),RNIJ(4),EI,EJ
      COMMON/BIKS/EIK(MB2,-MAB:MAB),IKIND(MB2)
      COMMON/BJLS/EJL(MB2,-MAB:MAB),JLIND(MB2)
      COMMON/BKLS/EKL(MB2,-MAB:MAB),RNKL(MB2,4),EK(MB2),EL(MB2)
      COMMON/BQNA/EXLA(MBS),EXLB(MBS),NBASA,NBASB,LQNA,LQNB,MAXM
      COMMON/BQNM/EXPT(MBS,4),MQN(4),KQN(4),LQN(4),NBAS(4),MAXM
      COMMON/FCTS/RFACT(0:20),SFACT(0:20)
      COMMON/GAMA/GAMLOG(50),GAMHLF(50)
      COMMON/RCFF/T0000,T1000,T0100,T0010,T0001,T1100,T1010,T1001,
     &            T0110,T0101,T0011,T1110,T1101,T1011,T0111,T1111,
     &            C1,C3,C5,C7,C9,V1,V2,V4,V8,VS
      COMMON/TANG/BK(MNU,4),ELL(MNU,4),ESS(MNU,4),ESL(MNU,4),GSL(MNU,4)
      COMMON/TNUS/NUS(MNU),NUI,NUF,NUNUM

MOLECULAR
      COMMON/BLOC/PAB1,PAB2,PCD1,PCD2,NA1,NB1,NC1,ND1,NA2,NB2,NC2,ND2,
     &            IBAS,JBAS,ILIN,NADDAB,NADDCD,NBAS
      COMMON/LSHF/SHLEV(3),SHLV
      COMMON/QNMS/LABICN(MDM),LABKQN(MDM),LABMQN(MDM)
      COMMON/SCRN/IMTX(MB2,11),ISCR(MB2),IMAP(MB2),IBCH,ITOG,MAXN
      COMMON/SWRZ/GDSC,BDSC

EQ-COEFFS
      COMMON/ACSS/INABCD(0:ML4,0:ML4,0:ML4),
     &             IVEC(MRC),JVEC(MRC),KVEC(MRC),LAMVEC(MRC)
      COMMON/CTSN/P(MB2),P2(MB2),P22(MB2),RKAB(MB2),PA2(MB2),PB2(MB2),
     &            PAX(MB2),PAY(MB2),PAZ(MB2),PBX(MB2),PBY(MB2),PBZ(MB2)
      COMMON/E0LL/E0LLFL(MFL,8),IAD0LL(MCT,MCT,MKP,MKP,MKP,MKP)
      COMMON/E0SS/E0SSFL(MFL,8),IAD0SS(MCT,MCT,MKP,MKP,MKP,MKP)
      COMMON/EILS/EILSFL(MFL,24),IADILS(MCT,MCT,MKP,MKP,MKP,MKP)
      COMMON/IQTT/IABLL,ICDLL,IABSS,ICDSS,IABLS,ICDLS
      COMMON/MAKE/IEAB,IECD,IRIJ(MBS,MBS)

PROPERTIES
      COMMON/PT1B/NHMINT,HMINT

VISUALS
      COMMON/PLOT/NPTYPE,PTYPE

TIMES
      COMMON/TCPU/TTOT,TATM,TSCF,TMPT,TMCF,TDMG,TPRP,TPLT
      COMMON/TATM/TTOT
      COMMON/TSCF/TC1B,TC1R,TC1F,TC1M,TCEC,TCRM,TCRR,TCC1,TCC2,TCMC,
     &            TB1B,TB1R,TB1F,TB1M,TBEC,TBRM,TBRR,TBC1,TBC2,TBMC,
     &            THMX,TC1T,TC2T,TB1T,TB2T,TEIG,TSCR,TTOT,
     &            TC1S,TC2S,TB1S,TB2S
      COMMON/TMMD/TELL,TESS,TELS,TRLL,TRSS,TRLS,TRBR
      COMMON/T2EL/F2ES(5,6),T2ES(5,6),N2EB(5,6),N2EI(5,6),N2ES(5,6)
      COMMON/TMCF/EMTY
      COMMON/TDMG/EMTY
      COMMON/TMPT/EMTY
      COMMON/TPRP/EMTY
      COMMON/TPLT/EMTY
      
      
      
      MDM = 1200
      MCT = 6
      MKP = 9
      MBS = 26
      MBD = 2*MBS
      MB2 = MBS*MBS
      LWK = 128*MBS,64*MDM
      MIT = 100    ,200
      MNU = MKP+1
      MAB = 2*MNU+6
      ML2 = MKP+1
      MEQ = (ML2+1)*(ML2+2)*(ML2+3)/6
      ML4 = 2*(MKP+1)
      MRC = (ML4+1)*(ML4+2)*(ML4+3)/6
      MLM = 30

      MFL = 10000000
      NMAX = 30
      MSER = 60
      NINT = 1801









































