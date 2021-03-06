      SUBROUTINE COULOMB
      IMPLICIT DOUBLE PRECISION (A-H,O-Z)
C**********************************************************************C
C                                                                      C
C    CCCCCC   OOOOOO  UU    UU LL      OOOOOO  MM       MM BBBBBBB     C
C   CC    CC OO    OO UU    UU LL     OO    OO MMM     MMM BB    BB    C
C   CC       OO    OO UU    UU LL     OO    OO MMMM   MMMM BB    BB    C
C   CC       OO    OO UU    UU LL     OO    OO MM MM MM MM BBBBBBB     C
C   CC       OO    OO UU    UU LL     OO    OO MM  MMM  MM BB    BB    C
C   CC    CC OO    OO UU    UU LL     OO    OO MM   M   MM BB    BB    C
C    CCCCCC   OOOOOO   UUUUUU  LLLLLLL OOOOOO  MM       MM BBBBBBB     C
C                                                                      C
C -------------------------------------------------------------------- C
C  COULOMB GENERATES ALL MANY-CENTRE ELECTRON REPULSION INTEGRALS IN   C
C  BATCHES AND ADDS THEM TO THE SCF CLOSED/OPEN-SHELL COULOMB MATRIX.  C
C  CALCULATIONS ARE MADE WITH A RELATIVISTIC MCMURCHIE-DAVIDSON SCHEME.C
C -------------------------------------------------------------------- C
C  TODO: THIS ROUTINE COULD BENEFIT FROM PARALLELISATION -- OPENMP.    C
C**********************************************************************C
      INCLUDE 'parameters.h'
      INCLUDE 'scfoptions.h'
C     INCLUDE 'omp_lib.h'
C
      DIMENSION EXL(MBS,4),XYZ(3,4),KQN(4),MQN(4),NBAS(4),LQN(4),JQN(4)
      DIMENSION ISCF(11,6),IFLG(11)
      DIMENSION INDEX(MCT,-(MEL+1):MEL,MKP),ICNT(4),ITN(2)
      DIMENSION MAPTTTT(4,4)
C
      COMPLEX*16 RR(MB2,16)
      COMPLEX*16 FOCK(MDM,MDM),OVLP(MDM,MDM),HNUC(MDM,MDM),
     &           HKIN(MDM,MDM),GDIR(MDM,MDM),GXCH(MDM,MDM),
     &           BDIR(MDM,MDM),BXCH(MDM,MDM),VUEH(MDM,MDM),
     &           QDIR(MDM,MDM),QXCH(MDM,MDM),WDIR(MDM,MDM),
     &           WXCH(MDM,MDM),CPLE(MDM,MDM)
C
      COMMON/BDIM/NDIM,NSKP,NOCC,NVRT
      COMMON/BSET/BEXL(MBS,0:MEL,MCT),BXYZ(3,MCT),LRGE(MCT,MKP,MKP+1),
     &            KAPA(MKP,MCT),NFNC(0:MEL,MCT),NKAP(MCT),IQNC(MCT),NCNT
      COMMON/E0LL/E0LLFL(MFL,4),IAD0LL(MCT,MCT,MKP,MKP,MKP,MKP)
      COMMON/E0SS/E0SSFL(MFL,4),IAD0SS(MCT,MCT,MKP,MKP,MKP,MKP)
      COMMON/I2EL/PAB1,PAB2,PCD1,PCD2,NA1,NB1,NC1,ND1,NA2,NB2,NC2,ND2,
     &            IBAS,JBAS,MCNT,NADDAB,NADDCD,NBAS,IQL,IQR
      COMMON/IQTT/IABLL,ICDLL,IABSS,ICDSS,IABLS,ICDLS,IABSL,ICDSL
      COMMON/IRCM/IEAB,IECD,IRIJ(MBS,MBS)
      COMMON/ISCR/IMTX(MB2,11),ISCR(MB2),IMAP(MB2),IBCH,ITOG,MAXN
      COMMON/LSHF/SHLEV(3),SHLV,ILEV
      COMMON/MTRX/FOCK,OVLP,HNUC,HKIN,GDIR,GXCH,BDIR,BXCH,VUEH,QDIR,
     &            QXCH,WDIR,WXCH,CPLE
      COMMON/QNMS/LABICN(MDM),LABKQN(MDM),LABMQN(MDM)
      COMMON/SHLL/ACFF,BCFF,FOPN,ICLS(MDM),IOPN(MDM),NCLS,NOPN,NOELEC
      COMMON/SWRZ/GDSC(MDM,MDM),BDSC(MDM,MDM)
      COMMON/T2EL/F2ES(5,6),T2ES(5,6),N2EB(5,6),N2EI(5,6),N2ES(5,6)
      COMMON/TSCF/TC1B,TC1R,TC1F,TC1M,TCEC,TCRM,TCRW,TCC1,TCC2,TCMC,
     &            TB1B,TB1R,TB1F,TB1M,TBEC,TBRM,TBRW,TBC1,TBC2,TBMC,
     &            TQMX,THMX,TC1T,TC2T,TCVT,TB1T,TB2T,TEIG,TSCR,TTOT,
     &            TC1S,TC2S,TB1S,TB2S
C
C     ISCF TELLS WHICH INTEGRALS TO INCLUDE BASED ON OVERLAP COMBINATION
      DATA ISCF/1,1,1,1,1,1,1,1,0,0,0,
     &          1,1,0,0,1,1,1,0,0,0,0,
     &          1,0,1,1,1,0,1,0,0,0,0,
     &          1,1,1,0,1,1,0,0,0,0,0,
     &          1,0,1,0,1,0,0,0,0,0,0,
     &          1,0,0,0,1,0,0,0,0,0,0/
C
C     TWO-ELECTRON COMPONENT OVERLAP ADDRESSES
      DATA MAPTTTT/1,0,0,2,0,5,6,0,0,7,8,0,3,0,0,4/
C
C     INTEGRAL SCREENING SENSITIVITY PARAMETER
      DATA SENS/1.0D-12/
C
C     INTEGRAL SKIPPING ON MOLECULAR GROUP SYMMETRY CLASS BASIS
      IF(SHAPE.EQ.'ATOMIC'.OR.SHAPE.EQ.'DIATOMIC'.OR.
     &                        SHAPE.EQ.'LINEAR') THEN
        ISYM = 1
      ELSE
        ISYM = 0
      ENDIF
C
C     COMPONENT OVERLAP LABELS TO LOOP OVER
      IF(HMLT.EQ.'BARE') THEN
        RETURN
      ELSEIF(HMLT.EQ.'NORL') THEN
        ITSTRT = 1
        ITSTOP = 1
        ITSKIP = 1
      ELSE
        ITSTRT = 4
        ITSTOP = 1
        ITSKIP =-3
      ENDIF
C
C     INITIALISE STORAGE MATRICES
      DO I=1,NDIM
        DO J=1,NDIM
          GDIR(I,J) = DCMPLX(0.0D0,0.0D0)
          GXCH(I,J) = DCMPLX(0.0D0,0.0D0)
          QDIR(I,J) = DCMPLX(0.0D0,0.0D0)
          QXCH(I,J) = DCMPLX(0.0D0,0.0D0)
        ENDDO
      ENDDO
C
C**********************************************************************C
C     ORDERED INDEX OF (ICNT,KQN,MQN) COMBINATIONS                     C
C**********************************************************************C
C
      ICOUNT = 0
C
C     LOOP OVER NUCLEAR CENTRES
      DO ICT=1,NCNT
C
C       LOOP OVER KAPPA VALUES FOR THIS NUCLEAR CENTRE
        DO KN=1,NKAP(ICT)
C
C         IMPORT KAPPA, MAXIMUM MQN
          KAPPA = KAPA(KN,ICT)
          MJMAX = 2*IABS(KAPPA)-1
C
C         LOOP OVER MQN VALUES AND RECORD INDEX
          DO MJ=1,MJMAX,2
            ICOUNT              = ICOUNT+1
            INDEX(ICT,KAPPA,MJ) = ICOUNT
          ENDDO
        ENDDO
      ENDDO
C
C**********************************************************************C
C     LOOP OVER ALL ATOMIC CENTRES (USE INDEX 1000)                    C
C**********************************************************************C
C
C     LOOP OVER CENTRE A
      DO 1000 ICNTA=1,NCNT
        ICNT(1) = ICNTA
C
C       CARTESIAN COORDINATES OF CENTRE A
        XYZ(1,1) = BXYZ(1,ICNTA)
        XYZ(2,1) = BXYZ(2,ICNTA)
        XYZ(3,1) = BXYZ(3,ICNTA)
C
C     LOOP OVER CENTRE B
      DO 1000 ICNTB=1,ICNTA
        ICNT(2) = ICNTB
C
C       CARTESIAN COORDINATES OF CENTRE B
        XYZ(1,2) = BXYZ(1,ICNTB)
        XYZ(2,2) = BXYZ(2,ICNTB)
        XYZ(3,2) = BXYZ(3,ICNTB)
C
C     LOOP OVER CENTRE C
      DO 1000 ICNTC=1,NCNT
        ICNT(3) = ICNTC
C
C       CARTESIAN COORDINATES OF CENTRE C
        XYZ(1,3) = BXYZ(1,ICNTC)
        XYZ(2,3) = BXYZ(2,ICNTC)
        XYZ(3,3) = BXYZ(3,ICNTC)
C
C     LOOP OVER CENTRE D
      DO 1000 ICNTD=1,NCNT
        ICNT(4) = ICNTD
C
C       CARTESIAN COORDINATES OF CENTRE D
        XYZ(1,4) = BXYZ(1,ICNTD)
        XYZ(2,4) = BXYZ(2,ICNTD)
        XYZ(3,4) = BXYZ(3,ICNTD)
C
C     NUMBER OF NUCLEAR CENTRES INVOLVED IN THIS OVERLAP
      MCNT = NCNTRS(ICNTA,ICNTB,ICNTC,ICNTD)
C
C     SKIP ONE-CENTRE CONTRIBUTIONS (DEFER TO RACAH ALGEBRA ROUTINE)
      IF(MCNT.EQ.1.AND.RACAH1) THEN
        GOTO 1001
      ENDIF
Cc      
C      DFWED
C      if(icnta.ne.icntb.or.icntc.ne.icntd) then
C        goto 1001
C      endif
C
C**********************************************************************C
C     LOOP OVER ALL KQN SYMMETRY TYPES (USE INDEX 2000)                C
C**********************************************************************C
C
C     LOOP OVER KQN(A) VALUES
      DO 2000 KA=1,NKAP(ICNTA)
C
C       QUANTUM NUMBERS FOR BLOCK A
        KQN(1) = KAPA(KA,ICNTA)
        IF(KQN(1).LT.0) THEN
          LQN(1) =-KQN(1)-1
        ELSE
          LQN(1) = KQN(1)
        ENDIF
        JQN(1) = 2*IABS(KQN(1))-1
C
C       BASIS EXPONENTS FOR BLOCK A
        NBAS(1) = NFNC(LQN(1),ICNTA)
        DO IBAS=1,NBAS(1)
          EXL(IBAS,1) = BEXL(IBAS,LQN(1),ICNTA)
        ENDDO
C
C     LOOP OVER KQN(B) VALUES
      DO 2000 KB=1,NKAP(ICNTB)
C
C       QUANTUM NUMBERS FOR BLOCK B
        KQN(2) = KAPA(KB,ICNTB)
        IF(KQN(2).LT.0) THEN
          LQN(2) =-KQN(2)-1
        ELSE
          LQN(2) = KQN(2)
        ENDIF
        JQN(2) = 2*IABS(KQN(2))-1
C
C       BASIS EXPONENTS FOR BLOCK B
        NBAS(2) = NFNC(LQN(2),ICNTB)
        DO JBAS=1,NBAS(2)
          EXL(JBAS,2) = BEXL(JBAS,LQN(2),ICNTB)
        ENDDO
C
C     LOOP OVER KQN(C) VALUES
      DO 2000 KC=1,NKAP(ICNTC)
C
C       QUANTUM NUMBERS FOR BLOCK C
        KQN(3) = KAPA(KC,ICNTC)
        IF(KQN(3).LT.0) THEN
          LQN(3) =-KQN(3)-1
        ELSE
          LQN(3) = KQN(3)
        ENDIF
        JQN(3) = 2*IABS(KQN(3))-1
C
C       BASIS EXPONENTS FOR BLOCK C
        NBAS(3) = NFNC(LQN(3),ICNTC)
        DO KBAS=1,NBAS(3)
          EXL(KBAS,3) = BEXL(KBAS,LQN(3),ICNTC)
        ENDDO
C
C     LOOP OVER KQN(D) VALUES
      DO 2000 KD=1,NKAP(ICNTD)
C
C       QUANTUM NUMBERS FOR BLOCK D
        KQN(4) = KAPA(KD,ICNTD)
        IF(KQN(4).LT.0) THEN
          LQN(4) =-KQN(4)-1
        ELSE
          LQN(4) = KQN(4)
        ENDIF
        JQN(4) = 2*IABS(KQN(4))-1
C
C       BASIS EXPONENTS FOR BLOCK D
        NBAS(4) = NFNC(LQN(4),ICNTD)
        DO LBAS=1,NBAS(4)
          EXL(LBAS,4) = BEXL(LBAS,LQN(4),ICNTD)
        ENDDO
C
C     THIS UNIQUELY DEFINES A FULL SET OF RC(AB|CD) INTEGRALS -- RESET
      DO IBAS=1,NBAS(1)
        DO JBAS=1,NBAS(2)
          IRIJ(IBAS,JBAS) = 1
        ENDDO
      ENDDO
C
C**********************************************************************C
C     MOLECULAR SELECTION RULES BASED ON KQN                           C
C**********************************************************************C
C
C     ATOM-CENTRED SELECTION RULES (ONLY APPLIES IF RACAH1 SWITCHED OFF)
      IF(MCNT.EQ.1) THEN
C
C       LQN PAIR PARITY (0 IF EVEN, 1 IF ODD)
        IPARAB = MOD(LQN(1)+LQN(2),2)
        IPARCD = MOD(LQN(3)+LQN(4),2)
C
C       LQN PAIR PARITY SELECTION RULE
        IF(IPARAB.NE.IPARCD) THEN
          GOTO 2001
        ENDIF
C
C       JQN TRIANGLE RULE CHECK FOR MULTIPOLE EXPANSION (ATOM-CENTRED)
        NUI = MAX0(IABS(JQN(1)-JQN(2))/2,IABS(JQN(3)-JQN(4))/2)
        NUF = MIN0(    (JQN(1)+JQN(2))/2,    (JQN(3)+JQN(4))/2)
        IF(NUI.GT.NUF) THEN
          GOTO 2001
        ENDIF
C
C       ADDITIONAL LQN SELECTION RULE PARITY ANALYSIS
        ISELK = 0
        DO NU=NUI,NUF
C
C         A AND B: LQN(1)+LQN(2)+NU EVEN OR ODD (0 IF EVEN, 1 IF ODD)
          IPARAB = MOD(LQN(1)+LQN(2)+NU,2)
          IPARCD = MOD(LQN(3)+LQN(4)+NU,2)
C
C         LQNA+LQNB+NU AND LQNC+LQND+NU ARE BOTH EVEN
          IF(IPARAB.EQ.0.AND.IPARCD.EQ.0) ISELK = 1
C
        ENDDO
        IF(ISELK.EQ.0) GOTO 2001
C
      ENDIF
C
C**********************************************************************C
C     LOOP OVER ALL |MQN| PROJECTIONS (INDEX 3000)                     C
C**********************************************************************C
C
C     LOOP OVER |MQN(A)| VALUES
      DO 3000 MA=1,IABS(KQN(1))
        MQN(1) = 2*MA-1
C
C     LOOP OVER |MQN(B)| VALUES
      DO 3000 MB=1,IABS(KQN(2))
        MQN(2) = 2*MB-1
C
C     EQ-COEFFICIENT STARTING ADDRESSES FOR (AB) PAIR
      IABLL = IAD0LL(ICNTA,ICNTB,KA,KB,MA,MB)
      IABSS = IAD0SS(ICNTA,ICNTB,KA,KB,MA,MB)
C
C     LOOP OVER |MQN(C)| VALUES
      DO 3000 MC=1,IABS(KQN(3))
        MQN(3) = 2*MC-1
C
C     LOOP OVER |MQN(D)| VALUES
      DO 3000 MD=1,IABS(KQN(4))
        MQN(4) = 2*MD-1
C
C     EQ-COEFFICIENT STARTING ADDRESSES FOR (CD) PAIR
      ICDLL = IAD0LL(ICNTC,ICNTD,KC,KD,MC,MD)
      ICDSS = IAD0SS(ICNTC,ICNTD,KC,KD,MC,MD)
C
C**********************************************************************C
C     MOLECULAR SELECTION RULES BASED ON MQN                           C
C**********************************************************************C
C
C     SPIN PROJECTION CONSERVED ALONG Z-AXIS FOR LINEAR MOLECULES
      IF(ISYM.EQ.1) THEN
        IF(MQN(1).EQ.MQN(2).AND.MQN(3).EQ.MQN(4)) GOTO 3003
        IF(MQN(1).EQ.MQN(3).AND.MQN(2).EQ.MQN(4)) GOTO 3003
        IF(MQN(1).EQ.MQN(4).AND.MQN(2).EQ.MQN(3)) GOTO 3003
        GOTO 3001
      ENDIF
3003  CONTINUE
C
C     ATOM-CENTRED SELECTION RULES (ONLY APPLIES IF RACAH1 SWITCHED OFF)
      IF(MCNT.EQ.1) THEN
        ISELM = 0
        DO ISGN1=1,2
          DO ISGN2=1,2
            DO ISGN3=1,2
              DO ISGN4=1,2
                MMJA = MQN(1)*((-1)**ISGN1)
                MMJB = MQN(2)*((-1)**ISGN2)
                MMJC = MQN(3)*((-1)**ISGN3)
                MMJD = MQN(4)*((-1)**ISGN4)
                IF(MMJA-MMJB.EQ.MMJD-MMJC) ISELM = 1
              ENDDO
            ENDDO
          ENDDO
        ENDDO
        IF(ISELM.EQ.0) GOTO 3001
      ENDIF
C
C**********************************************************************C
C     IDENTIFICATION OF ERI SYMMETRIES AVAILABLE TO THIS BLOCK         C
C**********************************************************************C
C
C     CALCULATE BLOCK INDICES FOR {ABCD} COMBINATIONS
      IQ1 = INDEX(ICNTA,KQN(1),MQN(1))
      IQ2 = INDEX(ICNTB,KQN(2),MQN(2))
      IQ3 = INDEX(ICNTC,KQN(3),MQN(3))
      IQ4 = INDEX(ICNTD,KQN(4),MQN(4))
C
C     COMBINED BLOCK INDEX IN A TWO-FUNCTION LIST
      IQL = (IQ1*(IQ1-1))/2 + IQ2
      IQR = (IQ3*(IQ3-1))/2 + IQ4
C
C     SKIP CONTRIBUTIONS THAT ARISE BY PERMUTATION OF INTEGRALS
      IF(IQ1.LT.IQ2) GOTO 3001
      IF(IQ3.LT.IQ4) GOTO 3001
      IF(IQL.LT.IQR) GOTO 3001
C
      IF(IQ1.GT.IQ2.AND.IQ3.GT.IQ4.AND.IQL.GT.IQR) THEN
C       IQ1 > IQ2, IQ3 > IQ4, IQL > IQR
        ITSCF = 1
      ELSEIF(IQ1.GT.IQ2.AND.IQ3.GT.IQ4.AND.IQL.EQ.IQR) THEN
C       IQ1 > IQ2, IQ3 > IQ4, IQL = IQR
        ITSCF = 2
      ELSEIF(IQ1.GT.IQ2.AND.IQ3.EQ.IQ4.AND.IQL.GT.IQR) THEN
C       IQ1 > IQ2, IQ3 = IQ4, IQL > IQR
        ITSCF = 3
      ELSEIF(IQ1.EQ.IQ2.AND.IQ3.GT.IQ4.AND.IQL.GT.IQR) THEN
C       IQ1 = IQ2, IQ3 > IQ4, IQL > IQR
        ITSCF = 4
      ELSEIF(IQ1.EQ.IQ2.AND.IQ3.EQ.IQ4.AND.IQL.GT.IQR) THEN
C       IQ1 = IQ2, IQ3 = IQ4, IQL > IQR
        ITSCF = 5
      ELSEIF(IQ1.EQ.IQ2.AND.IQ3.EQ.IQ4.AND.IQL.EQ.IQR) THEN
C       IQ1 = IQ2, IQ3 = IQ4, IQL = IQR
        ITSCF = 6
      ELSE
C       ALL OTHER CASES GENERATED BY THE ABOVE, SO SKIP
        GOTO 3001
      ENDIF
C
C     READ IN FLAG VALUES FROM ISCF DATA BLOCK
      DO IS=1,11
        IFLG(IS) = ISCF(IS,ITSCF)
      ENDDO
C
C     INCLUDE SPECIAL CASES FOR MATCHING BLOCKS
      IF(IQ2.EQ.IQ3) THEN
C       IQ2 = IQ3
        IF(ITSCF.EQ.1.OR.ITSCF.EQ.3.OR.ITSCF.EQ.4) THEN
          IFLG( 9) = 1
        ENDIF
      ENDIF
C
      IF(ITSCF.EQ.1) THEN
        IF(IQ1.EQ.IQ3) THEN
C         IQ1 = IQ3
          IFLG(10) = 1
        ELSEIF(IQ2.EQ.IQ4) THEN
C         IQ2 = IQ4
          IFLG(11) = 1
        ENDIF
      ENDIF
C
C     EQ-COEFFICIENT PHASE FACTORS FOR PERMUTATION OF R-INTEGRALS
      PAB1 = ISIGN(1,KQN(1)*KQN(2))*DFLOAT((-1)**((-MQN(1)+MQN(2))/2))
      PAB2 = ISIGN(1,KQN(1)*KQN(2))*DFLOAT((-1)**(( MQN(1)+MQN(2))/2))
      PCD1 = ISIGN(1,KQN(3)*KQN(4))*DFLOAT((-1)**((-MQN(3)+MQN(4))/2))
      PCD2 = ISIGN(1,KQN(3)*KQN(4))*DFLOAT((-1)**(( MQN(3)+MQN(4))/2))
C
C**********************************************************************C
C     LOOP OVER COMPONENT OVERLAP OPTIONS (INDEX 4000)                 C
C**********************************************************************C
C
C     LOOP OVER COMPONENT LABEL FOR A AND B: TT = LL (1) or SS (4)
      DO 4000 IT1=ITSTRT,ITSTOP,ITSKIP
C
C       PUT BLOCK VALUES INTO AN ARRAY FOR ERI ROUTINE LATER
        ITN(1) = IT1
C
C       CALCULATE STARTING ADDRESS
        IF(IT1.EQ.1) THEN
          NADDAB = 0
        ELSE
          NADDAB = NSKP
        ENDIF
C
C       FOCK ADDRESS FOR EACH BASIS FUNCTION (WITH SPIN PROJECTION)
        NA1 = LRGE(ICNTA,KA,2*MA-1) + NADDAB
        NA2 = LRGE(ICNTA,KA,2*MA  ) + NADDAB
        NB1 = LRGE(ICNTB,KB,2*MB-1) + NADDAB
        NB2 = LRGE(ICNTB,KB,2*MB  ) + NADDAB
C
C       FLAG READ-IN OF E0(AB) COEFFICIENTS FOR THIS COMPONENT LABEL
        IEAB = 1
C
C     LOOP OVER COMPONENT LABEL FOR C AND D: T'T' = LL (1) or SS (4)
      DO 4000 IT2=ITSTRT,ITSTOP,ITSKIP
C
C       PUT BLOCK VALUES INTO AN ARRAY FOR ERI ROUTINE LATER
        ITN(2) = IT2
C
C       CALCULATE STARTING ADDRESS
        IF(IT2.EQ.1) THEN
          NADDCD = 0
        ELSE
          NADDCD = NSKP
        ENDIF
C
C       FOCK ADDRESS FOR EACH BASIS FUNCTION (WITH SPIN PROJECTION)
        NC1 = LRGE(ICNTC,KC,2*MC-1) + NADDCD
        NC2 = LRGE(ICNTC,KC,2*MC  ) + NADDCD
        ND1 = LRGE(ICNTD,KD,2*MD-1) + NADDCD
        ND2 = LRGE(ICNTD,KD,2*MD  ) + NADDCD
C
C       FLAG READ-IN OF E0(CD) COEFFICIENTS FOR THIS COMPONENT LABEL
        IECD = 1
C
C     COMPONENT OVERLAP INDEX {(LL|LL)=1,(LL|SS)=2,(SS|LL)=3,(SS|SS)=4}
      ITT = MAPTTTT(IT1,IT2)
C
C     STAGE 1: INCLUDE ONLY (LL|LL) REPULSION INTEGRALS
      IF(ILEV.EQ.1.AND.ITT.GT.1) THEN
        GOTO 4001
      ENDIF
C
C     STAGE 2: INCLUDE ONLY (LL|SS) AND (SS|LL) REPULSION INTEGRALS
      IF(ILEV.EQ.2.AND.ITT.GT.3) THEN
        GOTO 4001
      ENDIF
C
C     STAGE 3: INCLUDE ONLY TWO-CENTRE (SS|SS) REPULSION INTEGRALS
      IF(ILEV.EQ.3.AND.ITT.EQ.4) THEN
C
        IF(SSSSI3.AND.MCNT.EQ.3) THEN
          GOTO 4001
        ENDIF
        IF(SSSSI4.AND.MCNT.EQ.4) THEN
          GOTO 4001
        ENDIF
C
c        IF(MCNT.EQ.2) THEN
cC         DIRECT CHOICE
c          IF(ICNTA.EQ.ICNTB.AND.ICNTC.EQ.ICNTD) THEN
c            GOTO 4002
cC         EXCHANGE CHOICE
c          ELSEIF(ICNTA.EQ.ICNTD.AND.ICNTB.EQ.ICNTC) THEN
c            GOTO 4002
c          ENDIF
c          GOTO 4001
cC         TODO: THIS IS WHERE I WOULD EVALUATE POINT-COULOMB RESULTS
c4002      CONTINUE
C        ENDIF
      ENDIF
      
C      IF(ITT.NE.4) GOTO 4001
C
C     UPDATE COUNTER FOR NUMBER OF CLASSES
      N2EB(MCNT,ITT) = N2EB(MCNT,ITT)+1
C
C**********************************************************************C
C     LOOP OVER BASIS FUNCTIONS (IBAS,JBAS) TO CONSTRUCT GMAT/QMAT     C
C**********************************************************************C
C
C     RECORD TIME AT START OF BATCH
      CALL CPU_TIME(TI)
C
C     START OF PARALLEL REGION
C!$OMP PARALLEL DO COLLAPSE(2)
C!$OMP&  PRIVATE(RR,IBCH,IFLG)
C!$OMP&  SHARED(XYZ,KQN,MQN,EXL,NBAS,ITN)
      DO IBAS=1,NBAS(1)
        DO JBAS=1,NBAS(2)
C
C         SCHWARZ SCREENING (ECONOMIC ONLY WHEN SCREENING FRACTION BIG)
          IF(SCHWRZ.AND.ITT.GT.1) THEN
            ITOG = 1
          ELSE
            ITOG = 0
          ENDIF
C
          CALL SCHWARZ(GDSC,SENS,TC2S)
C
C         UPDATE COUNTER FOR NUMBER OF INTEGRALS AND SCREENED INTEGRALS
          N2EI(MCNT,ITT) = N2EI(MCNT,ITT)+NBAS(3)*NBAS(4)
          N2ES(MCNT,ITT) = N2ES(MCNT,ITT)+NBAS(3)*NBAS(4)-MAXN
C
C         CONDITIONAL TO SKIP THIS BATCH
          IF(IBCH.EQ.1) THEN
C
C           GENERATE BATCH OF ELECTRON REPULSION INTEGRALS
            CALL ERI(RR,XYZ,KQN,MQN,NBAS,EXL,IBAS,JBAS,ITN)
C
C           MULTIPLY BY DENSITY ELEMENTS AND ADD TO GMAT/QMAT
            CALL CLMMAT(RR,IFLG,TCMC)
C
          ENDIF
C
        ENDDO
      ENDDO
C     END OF PARALLEL REGION
C!$OMP END PARALLEL DO
C
C     RECORD TIME AT END OF BATCH
      CALL CPU_TIME(TF)
      T2ES(MCNT,ITT) = T2ES(MCNT,ITT) + TF - TI
C
4001  CONTINUE
4000  CONTINUE
3001  CONTINUE
3000  CONTINUE
2001  CONTINUE
2000  CONTINUE
1001  CONTINUE
1000  CONTINUE
C
C**********************************************************************C
C     COMPLETE CONSTRUCTION OF ALL MATRICES BY CONJUGATION.            C
C**********************************************************************C
C
C     LOOP OVER LOWER TRIANGLE OF EACH TT' BLOCK
      DO J=1,NDIM-NSKP
        DO I=1,J
C
C         SMALL-COMPONENT ADDRESSES
          K = I+NSKP
          L = J+NSKP
C
C         SKIP DIAGONAL PARTS OF EACH SUB-BLOCK
          IF(LABICN(I).NE.LABICN(J)) GOTO 400
          IF(LABKQN(I).NE.LABKQN(J)) GOTO 400
          IF(IABS(LABMQN(I)).NE.IABS(LABMQN(J))) GOTO 400
          GOTO 401
400       CONTINUE
C
C         COMPLETE LOWER AND THEN UPPER TRIANGLE OF LL BLOCK
          GDIR(I,J) = GDIR(I,J) + DCONJG(GDIR(J,I))
          GDIR(J,I) =             DCONJG(GDIR(I,J))
          GXCH(I,J) = GXCH(I,J) + DCONJG(GXCH(J,I))
          GXCH(J,I) =             DCONJG(GXCH(I,J))
C
C         IF HMLT = 'NORL' SKIP THE NEXT FEW CALCULATIONS
          IF(HMLT.EQ.'NORL') GOTO 401
C
C         COMPLETE LOWER AND THEN UPPER TRIANGLE OF SS BLOCK
          GDIR(K,L) = GDIR(K,L) + DCONJG(GDIR(L,K))
          GDIR(L,K) =             DCONJG(GDIR(K,L))
          GXCH(K,L) = GXCH(K,L) + DCONJG(GXCH(L,K))
          GXCH(L,K) =             DCONJG(GXCH(K,L))
C
C         COMPLETE LOWER AND THEN UPPER TRIANGLE OF LS BLOCK
          GXCH(I,L) = GXCH(I,L) + DCONJG(GXCH(L,I))
          GXCH(L,I) =             DCONJG(GXCH(I,L))
C
C         COMPLETE LOWER AND THEN UPPER TRIANGLE OF SL BLOCK
          GXCH(K,J) = GXCH(K,J) + DCONJG(GXCH(J,K))
          GXCH(J,K) =             DCONJG(GXCH(K,J))
C
401       CONTINUE
        ENDDO
      ENDDO
C
C     OPEN-SHELL SPECIAL CASE
      IF(NOPN.EQ.0) GOTO 450
C
C     LOOP OVER LOWER TRIANGLE OF EACH TT' BLOCK
      DO J=1,NDIM-NSKP
        DO I=1,J
C
C         SMALL-COMPONENT ADDRESSES
          K = I+NSKP
          L = J+NSKP
C
C         SKIP DIAGONAL PARTS OF EACH SUB-BLOCK
          IF(LABICN(I).NE.LABICN(J)) GOTO 410
          IF(LABKQN(I).NE.LABKQN(J)) GOTO 410
          IF(IABS(LABMQN(I)).NE.IABS(LABMQN(J))) GOTO 410
          GOTO 402
410       CONTINUE
C
C         COMPLETE LOWER AND THEN UPPER TRIANGLE OF LL BLOCK
          QDIR(I,J) = QDIR(I,J) + DCONJG(QDIR(J,I))
          QDIR(J,I) =             DCONJG(QDIR(I,J))
          QXCH(I,J) = QXCH(I,J) + DCONJG(QXCH(J,I))
          QXCH(J,I) =             DCONJG(QXCH(I,J))
C
C         IF HMLT = 'NORL' SKIP THE NEXT FEW CALCULATIONS
          IF(HMLT.EQ.'NORL') GOTO 402
C
C         COMPLETE LOWER AND THEN UPPER TRIANGLE OF SS BLOCK
          QDIR(K,L) = QDIR(K,L) + DCONJG(QDIR(L,K))
          QDIR(L,K) =             DCONJG(QDIR(K,L))
          QXCH(K,L) = QXCH(K,L) + DCONJG(QXCH(L,K))
          QXCH(L,K) =             DCONJG(QXCH(K,L))
C
C         COMPLETE LOWER AND THEN UPPER TRIANGLE OF LS BLOCK
          QXCH(I,L) = QXCH(I,L) + DCONJG(QXCH(L,I))
          QXCH(L,I) =             DCONJG(QXCH(I,L))
C
C         COMPLETE LOWER AND THEN UPPER TRIANGLE OF SL BLOCK
          QXCH(K,J) = QXCH(K,J) + DCONJG(QXCH(J,K))
          QXCH(J,K) =             DCONJG(QXCH(K,J))
C
402       CONTINUE
        ENDDO
      ENDDO
C
C     MULTIPLY OPEN MATRIX BY ANGULAR COEFFICIENTS
      DO J=1,NDIM
        DO I=1,NDIM
          QDIR(I,J) = ACFF*QDIR(I,J)
          QXCH(I,J) = BCFF*QXCH(I,J)
        ENDDO
      ENDDO
C
C     CLOSED-SHELL SKIP POINT
450   CONTINUE
C
      RETURN
      END

