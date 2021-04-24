      SUBROUTINE MBPT2(MINO,NUMO,MINV,NUMV,G2INT)
      IMPLICIT DOUBLE PRECISION (A-H,O-Z)
C**********************************************************************C
C                                                                      C
C            MM       MM BBBBBBB  PPPPPPP TTTTTTTT 222222              C
C            MMM     MMM BB    BB PP    PP   TT   22    22             C
C            MMMM   MMMM BB    BB PP    PP   TT         22             C
C            MM MM MM MM BBBBBBB  PP    PP   TT       22               C
C            MM  MMM  MM BB    BB PPPPPPP    TT     22                 C
C            MM   M   MM BB    BB PP         TT   22                   C
C            MM       MM BBBBBBB  PP         TT   22222222             C
C                                                                      C
C -------------------------------------------------------------------- C
C  MBPT2 CALCULATES SECOND-ORDER PAIR CORRELATION CORRECTIONS OVER A   C
C  USER-SPECIFIED TWO-BODY OPERATOR. IT USES A RELATIVISTIC ADAPTION   C
C  OF THE DIRECT MP2 ALGORITHM OF HEAD-GORDON, POPLE AND FRISCH (1988).C
C  THIS IS NOT MOLLER-PLESSET PERTURBATION THEORY, SO CALL IT MBPT2.   C
C  ELECTRON REPULATION INTEGRALS ARE GENERATED ONCE, AT THE EXPENSE OF C
C  ADDITIONAL MEMORY STORAGE -- THEY ARE CONTRACTED IN FOUR STEPS.     C
C  THIS ALGORITHM EXPLOITS SYMMETRIES BETWEEN (A,B) AND (C,D) IN THE   C
C  INTEGRALS (AB|CD), BUT NOT THE SWAP (AB|CD)<->(CD|AB). STRUCTURE    C
C  MIMICS THAT OF 'COULOMB', BUT DOES NOT IMPLEMENT SELECTION RULES.   C
C  CONTRACTION ADDRESSES ARE CALCULATED EXPLICITLY RATHER THAN JUST    C
C  WITH UPDATING COUNTERS -- THIS IS TO GUIDE THE USER IN TRACKING.    C
C -------------------------------------------------------------------- C
C INPUT:                                                               C
C  MINO  - LOWEST OCCUPIED STATE TO ACCOUNT FOR. (FULL: 1)             C
C  NUMO  - NUMBER OF OCCUPIED STATES TO ACCOUNT FOR. (FULL: NOCC)      C
C  MINV  - LOWEST VIRTUAL STATE TO ACCOUNT FOR. (FULL: NOCC+1)         C
C  NUMV  - NUMBER OF VIRTUAL STATES TO ACCOUNT FOR. (FULL: NVRT)       C
C  G2INT - NAME OF TWO-BODY OPERATOR ('COULM' OR 'BREIT').             C
C -------------------------------------------------------------------- C
C NOTE: LOOP STRUCTURE IS DIFFERENT -- GOAL IS TO CONTRACT (CD) ASAP.  C
C**********************************************************************C
      PARAMETER(MDM=1200,MBS=26,MB2=MBS*MBS,MCT=15,MKP=9,MFL=7000000)
C
      CHARACTER*4 HMLTN
      CHARACTER*5 G2INT
      CHARACTER*16 HMS
      CHARACTER*40 MOLCL,WFNFL,OUTFL
C
      DIMENSION EXPT(MBS,4),XYZ(3,4),KQN(4),MQN(4),NBAS(4),LQN(4),ITN(2)
      DIMENSION ISCF(11,6),IFLG(11),ISCR(11)
      DIMENSION INDEX(MCT,-(MKP+1)/2:(MKP+1)/2,MKP)
      DIMENSION EAB2(NUMO,NUMO,6),EA2(NUMO,6)
C
      COMPLEX*16 RR(MB2,16),RNUMD,RNUMX,TEMP
      COMPLEX*16 C(MDM,MDM)
      COMPLEX*16 B1(NUMO*MBS,8),B2(NUMO*MBS,8)
      COMPLEX*16 SB(MB2,NUMO*NUMV,4)
      COMPLEX*16 ASB1(MBS,NUMO*NUMO*NUMV,2),ASB2(MBS,NUMO*NUMO*NUMV,2)
      COMPLEX*16 RASB((NUMO+1)*NUMO*NUMV*NUMV/2)
C
      COMMON/COEF/C
      COMMON/EIGN/EIGEN(MDM)
      COMMON/E0LL/E0LLFL(MFL,8),IAD0LL(MCT,MCT,MKP,MKP,MKP,MKP)
      COMMON/E0SS/E0SSFL(MFL,8),IAD0SS(MCT,MCT,MKP,MKP,MKP,MKP)
      COMMON/FLNM/MOLCL,WFNFL,OUTFL
      COMMON/IQTT/IABLL,ICDLL,IABSS,ICDSS,IABLS,ICDLS
      COMMON/MAKE/IEAB,IECD,IRIJ(MBS,MBS)
      COMMON/SPEC/EXPSET(MBS,MKP,MCT),COORD(3,MCT),ZNUC(MCT),AMASS(MCT),
     &            CNUC(MCT),PNUC,LARGE(MCT,MKP,MKP+1),NFUNCT(MKP,MCT),
     &            KVALS(MKP,MCT),IZNUC(MCT),IQNUC(MCT),LMAX(MCT),
     &            NKAP(MCT),NCNT,NDIM,NSHIFT,NOCC,NVRT
      COMMON/PRMS/CV,HMLTN,ITREE,IMOL,INEW,IEQS,IERC,IPAR,ICOR,ILEV
C
C     INCLUDE EXTRA OPENMP LIBRARY
      INCLUDE 'omp_lib.h'
C
C     WARNINGS BASED ON INVALID HMLTN VS. G2INT COMBINATIONS
      IF(G2INT.EQ.'COULM') THEN
        IF(HMLTN.EQ.'BARE') THEN
          WRITE(6, *) 'In MBPT2: HMLTN = BARE but G2INT = COULM.'
          WRITE(7, *) 'In MBPT2: HMLTN = BARE but G2INT = COULM.'
        ENDIF
      ELSEIF(G2INT.EQ.'BREIT') THEN
        IF(HMLTN.EQ.'NORL') THEN
          WRITE(6, *) 'In MBPT2: HMLTN = NORL but G2INT = BREIT.'
          WRITE(7, *) 'In MBPT2: HMLTN = NORL but G2INT = BREIT.'
          RETURN
        ELSEIF(HMLTN.EQ.'BARE') THEN
          WRITE(6, *) 'In MBPT2: HMLTN = BARE but G2INT = BREIT.'
          WRITE(7, *) 'In MBPT2: HMLTN = BARE but G2INT = BREIT.'
        ELSEIF(HMLTN.EQ.'DHFR') THEN
          WRITE(6, *) 'In MBPT2: HMLTN = DHFR but G2INT = BREIT.'
          WRITE(7, *) 'In MBPT2: HMLTN = DHFR but G2INT = BREIT.'
        ELSEIF(HMLTN.EQ.'DHFP') THEN
          WRITE(6, *) 'In MBPT2: HMLTN = DHFP but G2INT = BREIT.'
          WRITE(7, *) 'In MBPT2: HMLTN = DHFP but G2INT = BREIT.'
        ENDIF
      ENDIF
C
C     COMPONENT OVERLAP LABELS TO LOOP OVER
      IF(HMLTN.EQ.'BARE') THEN
        RETURN
      ELSEIF(HMLTN.EQ.'NORL') THEN
        IF(G2INT.EQ.'COULM') THEN
          ITSTRT = 1
          ITSTOP = 1
          ITSKIP = 1
        ENDIF
      ELSE
        IF(G2INT.EQ.'COULM') THEN
          ITSTRT = 1
          ITSTOP = 4
          ITSKIP = 3
        ELSEIF(G2INT.EQ.'BREIT') THEN
          ITSTRT = 2
          ITSTOP = 3
          ITSKIP = 1        
        ENDIF
      ENDIF
C
C     INITIALISE TIME COUNTERS
      TERI = 0.0D0
      TCN1 = 0.0D0
      TCN2 = 0.0D0
      TCN3 = 0.0D0
      TCN4 = 0.0D0
      TSUM = 0.0D0
C
C     SAVED BATCHES OF R(AB|CD) INTEGRALS IN ERI/BII
      IF(IEQS.EQ.0) THEN
        IERC = 0
      ELSE
        IERC = 1
      ENDIF
C
      CALL CPU_TIME(TBEG)
C
C     IMPORT MBPT1 PAIR RESULTS FOR E1(ab)
      OPEN(UNIT=8,FILE=TRIM(OUTFL)//'_MBPT1.dat',STATUS='UNKNOWN')
      REWIND(UNIT=8)
      DO IOCCA=1,NUMO
        DO IOCCB=1,NUMO
          READ(8, *) Q1,Q2,Q3,(EAB2(IOCCA,IOCCB,N),N=1,3)
        ENDDO
      ENDDO
      CLOSE(UNIT=8)
C
C     CLEAR THE REMAINDER OF THE CORRELATION PAIR ENERGY VALUES
      DO IOCCA=1,NUMO
        DO IOCCB=1,IOCCA
          DO N=4,6
            EAB2(IOCCA,IOCCB,N) = 0.0D0
          ENDDO
        ENDDO
      ENDDO
C
C     CLEAR THE ARRAY FOR (AR|BS) VALUES
      M = 0
      DO IVRTR=1,NUMV
        DO IOCCA=1,NUMO
          DO IOCCB=1,IOCCA
            DO IVRTS=1,NUMV
              M = M+1
              RASB(M) = DCMPLX(0.0D0,0.0D0)
            ENDDO
          ENDDO
        ENDDO
      ENDDO
C
C     CONSTRUCT ORDERED INDEX SYSTEM FOR ALL POSSIBLE {XYZ,KQN,MQN}
      ICOUNT = 0
C
C     LOOP OVER ATOMIC CENTERS
      DO ICT=1,NCNT
C
C       LOOP OVER KAPPA VALUES FOR THIS ATOMIC CENTER
        DO KN=1,NKAP(ICT)
C
C         IMPORT KAPPA, MAXIMUM MQN
          KAPPA = KVALS(KN,ICT)
          MJMAX = 2*IABS(KAPPA)-1
C
C         LOOP OVER MQN VALUES AND RECORD INDEX
          DO MJ=1,MJMAX,2
            ICOUNT = ICOUNT+1
            INDEX(ICT,KAPPA,MJ) = ICOUNT
          ENDDO
        ENDDO
      ENDDO
C
C**********************************************************************C
C     LOOP OVER COMPONENT OVERLAP OPTIONS (INDEX 1500)                 C
C**********************************************************************C
C
C     LOOP OVER COMPONENT LABEL FOR A AND B: TT = LL (1) or SS (4)
      DO 1500 IT1=ITSTRT,ITSTOP,ITSKIP
C
C       PUT BLOCK VALUES INTO AN ARRAY FOR ERI ROUTINE LATER
        ITN(1) = IT1
C
C       CALCULATE STARTING ADDRESS
        IF(IT1.EQ.1) THEN
          NADDAB = 0
        ELSE
          NADDAB = NSHIFT
        ENDIF
C
C     LOOP OVER COMPONENT LABEL FOR C AND D: T'T' = LL (1) or SS (4)
      DO 1500 IT2=ITSTRT,ITSTOP,ITSKIP
C
C       PRINT CURRENT COMPONENT OVERLAP
C        WRITE(6, *) 'MBPT2 OVERLAP: ',IT1,IT2
C        WRITE(7, *) 'MBPT2 OVERLAP: ',IT1,IT2
C
C       PUT BLOCK VALUES INTO AN ARRAY FOR ERI ROUTINE LATER
        ITN(2) = IT2
C
C       CALCULATE STARTING ADDRESS
        IF(IT2.EQ.1) THEN
          NADDCD = 0
        ELSE
          NADDCD = NSHIFT
        ENDIF
C
C     COMPONENT OVERLAP INDEX {(LL|LL)=1,(LL|SS)=2,(SS|LL)=3,(SS|SS)=4}
      ITT = (2*IT1+IT2)/3
C
C**********************************************************************C
C     LOOP OVER ATOMIC CENTERS WITH KQN A AND B (USE INDEX 2000)       C
C**********************************************************************C
C
C     LOOP OVER CENTER A
      DO 2000 ICNTA=1,NCNT
C
C       CARTESIAN COORDINATES OF CENTER A
        XYZ(1,1) = COORD(1,ICNTA)
        XYZ(2,1) = COORD(2,ICNTA)
        XYZ(3,1) = COORD(3,ICNTA)
C
C     LOOP OVER CENTER B
      DO 2000 ICNTB=1,ICNTA
C
C       CARTESIAN COORDINATES OF CENTER B
        XYZ(1,2) = COORD(1,ICNTB)
        XYZ(2,2) = COORD(2,ICNTB)
        XYZ(3,2) = COORD(3,ICNTB)
C
C     LOOP OVER KQN(A) VALUES
      DO 2000 KA=1,NKAP(ICNTA)
C
C       QUANTUM NUMBERS AND BASIS EXPONENTS FOR A
        KQN(1) = KVALS(KA,ICNTA)
        IF(KQN(1).GT.0) THEN
          LQN(1) = KQN(1)
        ELSE
          LQN(1) =-KQN(1)-1
        ENDIF
C
        NBAS(1) = NFUNCT(LQN(1)+1,ICNTA)
        DO IBAS=1,NBAS(1)
          EXPT(IBAS,1) = EXPSET(IBAS,LQN(1)+1,ICNTA)
        ENDDO
C
C     LOOP OVER KQN(B) VALUES
      DO 2000 KB=1,NKAP(ICNTB)
C
C       QUANTUM NUMBERS AND BASIS EXPONENTS FOR B
        KQN(2) = KVALS(KB,ICNTB)
        IF(KQN(2).GT.0) THEN
          LQN(2) = KQN(2)
        ELSE
          LQN(2) =-KQN(2)-1
        ENDIF
C
        NBAS(2) = NFUNCT(LQN(2)+1,ICNTB)
        DO JBAS=1, NBAS(2)
          EXPT(JBAS,2) = EXPSET(JBAS,LQN(2)+1,ICNTB)
        ENDDO
C
C**********************************************************************C
C     LOOP OVER ATOMIC CENTERS WITH KQN C AND D (USE INDEX 3000)       C
C**********************************************************************C
C
C     LOOP OVER CENTER C
      DO 3000 ICNTC=1,NCNT
C
C       CARTESIAN COORDINATES OF CENTER C
        XYZ(1,3) = COORD(1,ICNTC)
        XYZ(2,3) = COORD(2,ICNTC)
        XYZ(3,3) = COORD(3,ICNTC)
C
C     LOOP OVER CENTER D
      DO 3000 ICNTD=1,NCNT
C
C       CARTESIAN COORDINATES OF CENTER D
        XYZ(1,4) = COORD(1,ICNTD)
        XYZ(2,4) = COORD(2,ICNTD)
        XYZ(3,4) = COORD(3,ICNTD)
C
C     LOOP OVER KQN(C) VALUES
      DO 3000 KC=1,NKAP(ICNTC)
C
C       QUANTUM NUMBERS AND BASIS EXPONENTS FOR C
        KQN(3) = KVALS(KC,ICNTC)
        IF(KQN(3).GT.0) THEN
          LQN(3) = KQN(3)
        ELSE
          LQN(3) =-KQN(3)-1
        ENDIF
C
        NBAS(3) = NFUNCT(LQN(3)+1,ICNTC)
        DO KBAS=1,NBAS(3)
          EXPT(KBAS,3) = EXPSET(KBAS,LQN(3)+1,ICNTC)
        ENDDO
C
C     LOOP OVER KQN(D) VALUES
      DO 3000 KD=1,NKAP(ICNTD)
C
C       QUANTUM NUMBERS AND BASIS EXPONENTS FOR D
        KQN(4) = KVALS(KD,ICNTD)
        IF(KQN(4).GT.0) THEN
          LQN(4) = KQN(4)
        ELSE
          LQN(4) =-KQN(4)-1
        ENDIF
C
        NBAS(4) = NFUNCT(LQN(4)+1,ICNTD)
        DO LBAS=1,NBAS(4)
          EXPT(LBAS,4) = EXPSET(LBAS,LQN(4)+1,ICNTD)
        ENDDO
C
C     RESET RC(AB|CD) CLASS CALCULATION INDICATORS
      DO IBAS=1,NBAS(1)
        DO JBAS=1,NBAS(2)
          IRIJ(IBAS,JBAS) = 1
        ENDDO
      ENDDO
C
C**********************************************************************C
C     LOOP OVER ALL |MQN| VALUES (INDEX 4000)                          C
C**********************************************************************C
C
C     LOOP OVER |MQN(A)| VALUES
      DO 4000 MA=1,IABS(KQN(1))
        MQN(1) = 2*MA-1
C
C     LOOP OVER |MQN(B)| VALUES
      DO 4000 MB=1,IABS(KQN(2))
        MQN(2) = 2*MB-1
C
C     CALCULATE NEW BLOCK OF E(AB|  ) COEFFS AT NEXT OPPORTUNITY
      IEAB  = 1
      IABLL = IAD0LL(ICNTA,ICNTB,KA,KB,MA,MB)
      IABSS = IAD0SS(ICNTA,ICNTB,KA,KB,MA,MB)
C
C     LOOP OVER |MQN(C)| VALUES
      DO 4000 MC=1,IABS(KQN(3))
        MQN(3) = 2*MC-1
C
C     LOOP OVER |MQN(D)| VALUES
      DO 4000 MD=1,IABS(KQN(4))
        MQN(4) = 2*MD-1
C
C     CALCULATE NEW BLOCK OF E(CD|  ) COEFFS AT NEXT OPPORTUNITY
      IECD  = 1
      ICDLL = IAD0LL(ICNTC,ICNTD,KC,KD,MC,MD)
      ICDSS = IAD0SS(ICNTC,ICNTD,KC,KD,MC,MD)
C
C**********************************************************************C
C     INDEX ASSIGNMENT AND IDENTIFICATION OF ERI SYMMETRY CLASSES      C
C**********************************************************************C
C
      IQ1 = INDEX(ICNTA,KQN(1),MQN(1))
      IQ2 = INDEX(ICNTB,KQN(2),MQN(2))
      IQ3 = INDEX(ICNTC,KQN(3),MQN(3))
      IQ4 = INDEX(ICNTD,KQN(4),MQN(4))
C
C     SKIP CONTRIBUTIONS THAT ARISE BY PERMUTATION OF INTEGRALS
      IF(IQ1.LT.IQ2) GOTO 4001
      IF(IQ3.LT.IQ4) GOTO 4001
C
C**********************************************************************C
C     PHASE FACTORS APPROPRIATE TO INTEGRAL SYMMETRY CLASSES           C
C**********************************************************************C
C
C     EQ-COEFFICIENT PHASE FACTORS FOR PERMUTATION OF R-INTEGRALS
      PAB1 = ISIGN(1,KQN(1)*KQN(2))*DFLOAT((-1)**((-MQN(1)+MQN(2))/2))
      PAB2 = ISIGN(1,KQN(1)*KQN(2))*DFLOAT((-1)**(( MQN(1)+MQN(2))/2))
      PCD1 = ISIGN(1,KQN(3)*KQN(4))*DFLOAT((-1)**((-MQN(3)+MQN(4))/2))
      PCD2 = ISIGN(1,KQN(3)*KQN(4))*DFLOAT((-1)**(( MQN(3)+MQN(4))/2))
C
C     FOCK ADDRESS FOR EACH BASIS FUNCTION (WITH SPIN PROJECTION)
      NA1 = LARGE(ICNTA,KA,2*MA-1) + NADDAB
      NB1 = LARGE(ICNTB,KB,2*MB-1) + NADDAB
      NC1 = LARGE(ICNTC,KC,2*MC-1) + NADDCD
      ND1 = LARGE(ICNTD,KD,2*MD-1) + NADDCD
C
      NA2 = LARGE(ICNTA,KA,2*MA  ) + NADDAB
      NB2 = LARGE(ICNTB,KB,2*MB  ) + NADDAB
      NC2 = LARGE(ICNTC,KC,2*MC  ) + NADDCD
      ND2 = LARGE(ICNTD,KD,2*MD  ) + NADDCD
C
C     CLEAR ARRAY FOR THE COMPLETED CONTRACTION OVER BLOCKS C AND D
      DO MSB=1,NUMO*NUMV
        DO MIJ=1,NBAS(1)*NBAS(2)
          DO IJSPIN=1,4
            SB(MIJ,MSB,IJSPIN) = DCMPLX(0.0D0,0.0D0)
          ENDDO
        ENDDO
      ENDDO
C
C**********************************************************************C
C     LOOP OVER BASIS FUNCTIONS IN BLOCKS A AND B (INDEX 5000)         C
C**********************************************************************C
C
      DO 5000 IBAS=1,NBAS(1)
      DO 5000 JBAS=1,NBAS(2)
C
C     LIST ADDRESS FOR THIS IBAS,JBAS COMBINATION
      MIJ = (IBAS-1)*NBAS(2) + JBAS
C
C     BATCH OF ELECTRON INTERACTION INTEGRALS (IJ|KL) FOR FIXED (IJ)
      CALL CPU_TIME(T1)
      IF(G2INT.EQ.'COULM') THEN
        CALL ERI(RR,XYZ,KQN,MQN,EXPT,NBAS,ITN,IBAS,JBAS)
      ELSEIF(G2INT.EQ.'BREIT') THEN
        CALL BII(RR,XYZ,KQN,MQN,EXPT,NBAS,IBAS,JBAS)
      ENDIF
      CALL CPU_TIME(T2)
      TERI = TERI + T2 - T1
C
C     CLEAR ARRAY FOR FIRST CONTRACTION (DIRECT)
      DO MKB=1,NBAS(3)*NUMO
        DO IJKSPIN=1,8
          B1(MKB,IJKSPIN) = DCMPLX(0.0D0,0.0D0)
        ENDDO
      ENDDO
C
C     CLEAR ARRAY FOR FIRST CONTRACTION (SWAP)
      DO MLB=1,NBAS(4)*NUMO
        DO IJLSPIN=1,8
          B2(MLB,IJLSPIN) = DCMPLX(0.0D0,0.0D0)
        ENDDO
      ENDDO
C
C**********************************************************************C
C     FIRST CONTRACTION:                                               C
C     (IJ;T|KL;T') -> (IJ;T|KB;T')  AND  (IJ;T|LK;T') -> (IJ;T|LB;T')  C
C**********************************************************************C
C
      CALL CPU_TIME(T1)
C
C     FIRST CONTRACTION (DIRECT): (IJ;T|KL;T') -> (IJ;T|KB;T')
C
C     LOOP OVER BASIS FUNCTIONS IN BLOCK C AND OCCUPIED STATES IOCCB
      DO KBAS=1,NBAS(3)
        DO IOCCB=1,NUMO
C
C         FOCK MATRIX ADDRESS FOR IOCCB
          IB = MINO-1+IOCCB+NSHIFT
C
C         LIST ADDRESS FOR THIS KBAS,IOCCB COMBINATION
          MKB = (KBAS-1)*NUMO + IOCCB
C
C         LOOP OVER BASIS FUNCTIONS IN BLOCK D AND CONTRACT OVER ERI
          DO LBAS=1,NBAS(4)
C
C           LIST ADDRESS FOR THIS KBAS,LBAS COMBINATION
            M = (KBAS-1)*NBAS(4) + LBAS
C
C           (--|-B) = (--|--) + (--|-+)
            B1(MKB,1) = B1(MKB,1) +      RR(M, 1)*C(ND1+LBAS,IB)
     &                            +      RR(M, 2)*C(ND2+LBAS,IB)
C           (+-|-B) = (+-|--) + (+-|-+)
            B1(MKB,2) = B1(MKB,2) +      RR(M, 9)*C(ND1+LBAS,IB)
     &                            +      RR(M,10)*C(ND2+LBAS,IB)
C           (-+|-B) = (-+|--) + (-+|-+)
            B1(MKB,3) = B1(MKB,3) +      RR(M, 5)*C(ND1+LBAS,IB)
     &                            +      RR(M, 6)*C(ND2+LBAS,IB)
C           (++|-B) = (++|--) + (++|-+)
            B1(MKB,4) = B1(MKB,4) +      RR(M,13)*C(ND1+LBAS,IB)
     &                            +      RR(M,14)*C(ND2+LBAS,IB)
C           (--|+B) = (--|+-) + (--|++)
            B1(MKB,5) = B1(MKB,5) +      RR(M, 3)*C(ND1+LBAS,IB)
     &                            +      RR(M, 4)*C(ND2+LBAS,IB)
C           (+-|+B) = (+-|+-) + (+-|++)
            B1(MKB,6) = B1(MKB,6) +      RR(M,11)*C(ND1+LBAS,IB)
     &                            +      RR(M,12)*C(ND2+LBAS,IB)
C           (-+|+B) = (-+|+-) + (-+|++)
            B1(MKB,7) = B1(MKB,7) +      RR(M, 7)*C(ND1+LBAS,IB)
     &                            +      RR(M, 8)*C(ND2+LBAS,IB)
C           (++|+B) = (++|+-) + (++|++)
            B1(MKB,8) = B1(MKB,8) +      RR(M,15)*C(ND1+LBAS,IB)
     &                            +      RR(M,16)*C(ND2+LBAS,IB)
          ENDDO
        ENDDO
      ENDDO
C
C     FIRST CONTRACTION (SWAP): (IJ;T|LK;T') -> (IJ;T|LB;T')
      IF(IQ3.EQ.IQ4) GOTO 5100
C
C     LOOP OVER BASIS FUNCTIONS IN BLOCK D AND OCCUPIED STATES IOCCB
      DO LBAS=1,NBAS(4)
        DO IOCCB=1,NUMO
C
C         FOCK MATRIX ADDRESS FOR IOCCB
          IB = MINO-1+IOCCB+NSHIFT
C
C         LIST ADDRESS FOR THIS LBAS,IOCCB COMBINATION
          MLB = (LBAS-1)*NUMO + IOCCB
C
C         LOOP OVER BASIS FUNCTIONS IN BLOCK C AND CONTRACT OVER ERI
          DO KBAS=1,NBAS(3)
C
C           LIST ADDRESS FOR THIS KBAS,LBAS COMBINATION
            M = (KBAS-1)*NBAS(4) + LBAS
C
C           (--|+B) = PAB*{(--|B+)} = PAB*{(--|++) + ((--|-+))}
            B2(MLB,1) = B2(MLB,1) + PCD1*RR(M, 4)*C(NC1+KBAS,IB)
     &                            + PCD2*RR(M, 2)*C(NC2+KBAS,IB)
C           (+-|+B) = PAB*{(+-|B+)} = PAB*{(+-|++) + ((+-|-+))}
            B2(MLB,2) = B2(MLB,2) + PCD1*RR(M,12)*C(NC1+KBAS,IB)
     &                            + PCD2*RR(M,10)*C(NC2+KBAS,IB)
C           (-+|+B) = PAB*{(-+|B+)} = PAB*{(-+|++) + ((-+|-+))}
            B2(MLB,3) = B2(MLB,3) + PCD1*RR(M, 8)*C(NC1+KBAS,IB)
     &                            + PCD2*RR(M, 6)*C(NC2+KBAS,IB)
C           (++|+B) = PAB*{(++|B+)} = PAB*{(++|++) + ((++|-+))}
            B2(MLB,4) = B2(MLB,4) + PCD1*RR(M,16)*C(NC1+KBAS,IB)
     &                            + PCD2*RR(M,14)*C(NC2+KBAS,IB)
C           (--|-B) = PAB*{(--|B-)} = PAB*{(--|+-) + ((--|--))}
            B2(MLB,5) = B2(MLB,5) + PCD2*RR(M, 3)*C(NC1+KBAS,IB)
     &                            + PCD1*RR(M, 1)*C(NC2+KBAS,IB)
C           (+-|-B) = PAB*{(+-|B-)} = PAB*{(+-|+-) + ((+-|--))}
            B2(MLB,6) = B2(MLB,6) + PCD2*RR(M,11)*C(NC1+KBAS,IB)
     &                            + PCD1*RR(M, 9)*C(NC2+KBAS,IB)
C           (-+|-B) = PAB*{(-+|B-)} = PAB*{(-+|+-) + ((-+|--))}
            B2(MLB,7) = B2(MLB,7) + PCD2*RR(M, 7)*C(NC1+KBAS,IB)
     &                            + PCD1*RR(M, 5)*C(NC2+KBAS,IB)
C           (++|-B) = PAB*{(++|B-)} = PAB*{(++|+-) + ((++|--))}
            B2(MLB,8) = B2(MLB,8) + PCD2*RR(M,15)*C(NC1+KBAS,IB)
     &                            + PCD1*RR(M,13)*C(NC2+KBAS,IB)
          ENDDO
        ENDDO
      ENDDO
C
C     SKIP POINT FOR IQ3 = IQ4
5100  CONTINUE
C
      CALL CPU_TIME(T2)
      TCN1 = TCN1 + T2 - T1
C
C**********************************************************************C
C     SECOND CONTRACTION:                                      ~       C
C     (IJ;T|KB;T') -> (IJ;T|SB;T')  AND  (IJ;T|LB;T') -> (IJ;T|SB;T')  C
C**********************************************************************C
C
      CALL CPU_TIME(T1)
C
C     SECOND CONTRACTION (DIRECT): (IJ;T|KB;T') -> (IJ;T|SB;T')
C
C     LOOP OVER OCCUPIED STATES IOCCB AND VIRTUAL STATES IVRTS
      DO IOCCB=1,NUMO
        DO IVRTS=1,NUMV
C
C         FOCK MATRIX ADDRESS FOR IVRTS
          IS = MINV-1+IVRTS+NSHIFT
C
C         LIST ADDRESS FOR THIS IVRTS,IOCCB COMBINATION IN B1
          MSB = (IOCCB-1)*NUMV + IVRTS
C
C         LOOP OVER BASIS FUNCTIONS IN BLOCK C AND CONTRACT OVER B1
          DO KBAS=1,NBAS(3)
C
C           LIST ADDRESS FOR THIS KBAS,IOCCB COMBINATION
            MKB = (KBAS-1)*NUMO + IOCCB
C
C           (--|SB) = (--|-B) + (--|+B)
            SB(MIJ,MSB,1) = SB(MIJ,MSB,1)
     &                    + B1(MKB,1)*DCONJG(C(NC1+KBAS,IS))
     &                    + B1(MKB,5)*DCONJG(C(NC2+KBAS,IS))
C           (-+|SB) = (-+|-B) + (-+|+B)
            SB(MIJ,MSB,2) = SB(MIJ,MSB,2)
     &                    + B1(MKB,3)*DCONJG(C(NC1+KBAS,IS))
     &                    + B1(MKB,7)*DCONJG(C(NC2+KBAS,IS))
C           (+-|SB) = (+-|-B) + (+-|+B)
            SB(MIJ,MSB,3) = SB(MIJ,MSB,3)
     &                    + B1(MKB,2)*DCONJG(C(NC1+KBAS,IS))
     &                    + B1(MKB,6)*DCONJG(C(NC2+KBAS,IS))
C           (++|SB) = (++|-B) + (++|+B)
            SB(MIJ,MSB,4) = SB(MIJ,MSB,4)
     &                    + B1(MKB,4)*DCONJG(C(NC1+KBAS,IS))
     &                    + B1(MKB,8)*DCONJG(C(NC2+KBAS,IS))
          ENDDO
        ENDDO
      ENDDO
C                                                      ~
C     SECOND CONTRACTION (SWAP): (IJ;T|LB;T') -> (IJ;T|SB;T')
      IF(IQ3.EQ.IQ4) GOTO 5200
C
C     LOOP OVER OCCUPIED STATES IOCCB AND VIRTUAL STATES IVRTS
      DO IOCCB=1,NUMO
        DO IVRTS=1,NUMV
C
C         FOCK MATRIX ADDRESS FOR IVRTS
          IS = MINV-1+IVRTS+NSHIFT
C
C         LIST ADDRESS FOR THIS IVRTS,IOCCB COMBINATION IN B1
          MSB = (IOCCB-1)*NUMV + IVRTS
C
C         LOOP OVER BASIS FUNCTIONS IN BLOCK D AND CONTRACT OVER B2
          DO LBAS=1,NBAS(4)
C
C           LIST ADDRESS FOR THIS LBAS,IOCCB COMBINATION
            MLB = (LBAS-1)*NUMO + IOCCB
C
C           (--|$B) = (--|+B) + (--|-B)
            SB(MIJ,MSB,1) = SB(MIJ,MSB,1)
     &                    + B2(MLB,1)*DCONJG(C(ND1+LBAS,IS))
     &                    + B2(MLB,5)*DCONJG(C(ND2+LBAS,IS))
C           (-+|$B) = (-+|+B) + (-+|-B)
            SB(MIJ,MSB,2) = SB(MIJ,MSB,2)
     &                    + B2(MLB,3)*DCONJG(C(ND1+LBAS,IS))
     &                    + B2(MLB,7)*DCONJG(C(ND2+LBAS,IS))
C           (+-|$B) = (+-|+B) + (+-|-B)
            SB(MIJ,MSB,3) = SB(MIJ,MSB,3)
     &                    + B2(MLB,2)*DCONJG(C(ND1+LBAS,IS))
     &                    + B2(MLB,6)*DCONJG(C(ND2+LBAS,IS))
C           (++|$B) = (++|+B) + (++|-B)
            SB(MIJ,MSB,4) = SB(MIJ,MSB,4)
     &                    + B2(MLB,4)*DCONJG(C(ND1+LBAS,IS))
     &                    + B2(MLB,8)*DCONJG(C(ND2+LBAS,IS))
          ENDDO
        ENDDO
      ENDDO
C
C     SKIP POINT FOR IQ3 = IQ4
5200  CONTINUE
C
      CALL CPU_TIME(T2)
      TCN2 = TCN2 + T2 - T1
C
5000  CONTINUE
C
C     SB ARRAY NOW CONTAINS THE PARTIALLY-TRANSFORMED LIST: (IJ,SB)
C
C**********************************************************************C
C     THIRD CONTRACTION:                                               C
C     (IJ;T|SB;T') -> (IA;T|SB;T')  AND  (JI;T|SB;T') -> (JA;T|SB;T')  C
C**********************************************************************C
C
      CALL CPU_TIME(T1)
C
C     THIRD CONTRACTION (DIRECT): (IJ;T|SB;T') -> (IA;T|SB;T')
C
C     CLEAR ARRAY FOR THIRD CONTRACTION (DIRECT)
      DO MASB=1,NUMV*NUMO*NUMO
        DO IBAS=1,NBAS(1)
          DO ISPIN=1,2
            ASB1(IBAS,MASB,ISPIN) = DCMPLX(0.0D0,0.0D0)
          ENDDO
        ENDDO
      ENDDO
C
C     LOOP OVER OCCUPIED STATES IOCCA
      DO IOCCA=1,NUMO
C
C       FOCK MATRIX ADDRESS FOR IOCCA
        IA = MINO-1+IOCCA+NSHIFT
C
C       LOOP OVER OCCUPIED STATES IOCCB AND VIRTUAL STATES IVRTS
        DO IOCCB=1,IOCCA
          DO IVRTS=1,NUMV
C
C           LIST ADDRESS FOR THIS IVRTS,IOCCB COMBINATION
            MSB = (IOCCB-1)*NUMV+IVRTS
C
C           LIST ADDRESS FOR THIS IOCCA AND THE ABOVE MSB
            MASB = (IOCCA-1)*NUMV*NUMO + MSB
C
C           LOOP OVER BASIS FUNCTIONS IN A AND B, CONTRACT OVER SB
            DO IBAS=1,NBAS(1)
              DO JBAS=1,NBAS(2)
C
C               LIST ADDRESS FOR THIS IBAS,JBAS COMBINATION
                MIJ = (IBAS-1)*NBAS(2)+JBAS
C
C               (-A|SB) = (--|SB) + (-+|SB)
                ASB1(IBAS,MASB,1) = ASB1(IBAS,MASB,1)
     &                      +      SB(MIJ,MSB,1)*C(NB1+JBAS,IA)
     &                      +      SB(MIJ,MSB,2)*C(NB2+JBAS,IA)
C               (+A|SB) = (+-|SB) + (++|SB)
                ASB1(IBAS,MASB,2) = ASB1(IBAS,MASB,2)
     &                      +      SB(MIJ,MSB,3)*C(NB1+JBAS,IA)
     &                      +      SB(MIJ,MSB,4)*C(NB2+JBAS,IA)
C
              ENDDO
            ENDDO
          ENDDO
        ENDDO
      ENDDO
C
C     THIRD CONTRACTION (SWAP): (JI;T|SB;T') -> (JA;T|SB;T')
      IF(IQ1.EQ.IQ2) GOTO 5300
C
C     CLEAR ARRAY FOR THIRD CONTRACTION (SWAP)
      DO MASB=1,NUMV*NUMO*NUMO
        DO JBAS=1,NBAS(2)
          DO JSPIN=1,2
            ASB2(JBAS,MASB,JSPIN) = DCMPLX(0.0D0,0.0D0)
          ENDDO
        ENDDO
      ENDDO
C
C     LOOP OVER OCCUPIED STATES IOCCA
      DO IOCCA=1,NUMO
C
C       FOCK MATRIX ADDRESS FOR IOCCA
        IA = MINO-1+IOCCA+NSHIFT
C
C       LOOP OVER OCCUPIED STATES IOCCB AND VIRTUAL STATES IVRTS
        DO IOCCB=1,IOCCA
          DO IVRTS=1,NUMV
C
C           LIST ADDRESS FOR THIS IVRTS,IOCCB COMBINATION
            MSB = (IOCCB-1)*NUMV+IVRTS
C
C           LIST ADDRESS FOR THIS IOCCA AND THE ABOVE MSB
            MASB = (IOCCA-1)*NUMV*NUMO + MSB
C
C           LOOP OVER BASIS FUNCTIONS IN A AND B, CONTRACT OVER SB
            DO IBAS=1,NBAS(1)
              DO JBAS=1,NBAS(2)
C
C               LIST ADDRESS FOR THIS IBAS,JBAS COMBINATION
                MIJ = (IBAS-1)*NBAS(2)+JBAS
C
C               (+A|SB) = PCD*{(+A|SB)} = PCD*{(++|SB) + (-+|SB)}
                ASB2(JBAS,MASB,1) = ASB2(JBAS,MASB,1)
     &                      + PAB1*SB(MIJ,MSB,4)*C(NA1+IBAS,IA)
     &                      + PAB2*SB(MIJ,MSB,2)*C(NA2+IBAS,IA)
C               (-A|SB) = PCD*{(-A|SB)} = PCD*{(+-|SB) + (--|SB)}
                ASB2(JBAS,MASB,2) = ASB2(JBAS,MASB,2)
     &                      + PAB2*SB(MIJ,MSB,3)*C(NA1+IBAS,IA)
     &                      + PAB1*SB(MIJ,MSB,1)*C(NA2+IBAS,IA)
C
              ENDDO
            ENDDO
          ENDDO
        ENDDO
      ENDDO
C
C     SKIP POINT FOR IQ1 = IQ2
5300  CONTINUE
C
      CALL CPU_TIME(T2)
      TCN3 = TCN3 + T2 - T1
C
C**********************************************************************C
C     FOURTH CONTRACTION:                                 ~            C
C     (IA;T|SB;T') -> (RA;T|SB;T')  AND  (JA;T|SB;T') -> (RA;T|SB;T')  C
C**********************************************************************C
C
      CALL CPU_TIME(T1)
      T1 = OMP_GET_WTIME()
C
C     FOURTH CONTRACTION (DIRECT): (IA;T|SB;T') -> (RA;T|SB;T')
C
C     INITIALISE AN OPENMP PARALLEL REGION
CC$OMP PARALLEL DO COLLAPSE(2)
CC$OMP&  SHARED(RASB,ASB1,C)
CC$OMP&  PRIVATE(IR,IOCCB,IVRTS,MSB,MASB,MRASB,IBAS,TEMP)
C
C     LOOP OVER OCCUPIED STATES IOCCA AND VIRTUAL STATES IVRTR
      DO IOCCA=1,NUMO
        DO IVRTR=1,NUMV
C
C         FOCK MATRIX ADDRESS FOR IVRTR
          IR = MINV-1+IVRTR+NSHIFT
C
C         LOOP OVER OCCUPIED STATES IOCCB AND VIRTUAL STATES IVRTS
          DO IOCCB=1,IOCCA
            DO IVRTS=1,NUMV
C
C             LIST ADDRESS FOR THIS IVRTS,IOCCB COMBINATION
              MSB = (IOCCB-1)*NUMV + IVRTS
C
C             LIST ADDRESS FOR THIS IOCCA AND THE ABOVE MSB
              MASB = (IOCCA-1)*NUMV*NUMO + MSB
C
C             LOOP OVER BASIS FUNCTIONS IN BLOCK A, CONTRACT OVER ASB1
              TEMP = DCMPLX(0.0D0,0.0D0)
C
              DO IBAS=1,NBAS(1)
C
C               (RA|SB) = (-A|SB) + (+A|SB)
                TEMP = TEMP + ASB1(IBAS,MASB,1)*DCONJG(C(NA1+IBAS,IR))
     &                      + ASB1(IBAS,MASB,2)*DCONJG(C(NA2+IBAS,IR))
C
              ENDDO
C
C             LIST ADDRESS FOR THIS IVRTR,IOCCA AND THE ABOVE MSB
              MRASB = (IOCCA-1)*NUMV*IOCCA*NUMV/2
     &              + (IVRTR-1)*NUMV*IOCCA + MSB
C
C             UPDATE RASB VALUE
              RASB(MRASB) = RASB(MRASB) + TEMP
C
            ENDDO
          ENDDO
        ENDDO
      ENDDO
C     CLOSE THE OPENMP PARALLEL REGION
CC$OMP END PARALLEL DO
C                                                 ~
C     FOURTH CONTRACTION (SWAP): (JA;T|SB;T') -> (RA;T|SB;T')
      IF(IQ1.EQ.IQ2) GOTO 5400
C
C     INITIALISE AN OPENMP PARALLEL REGION
CC$OMP PARALLEL DO COLLAPSE(2)
CC$OMP&  SHARED(RASB,ASB2,C)
CC$OMP&  PRIVATE(IR,IOCCB,IVRTS,MSB,MASB,MRASB,JBAS,TEMP)
C
C     LOOP OVER OCCUPIED STATES IOCCA AND VIRTUAL STATES IVRTR
      DO IOCCA=1,NUMO
        DO IVRTR=1,NUMV
C
C         FOCK MATRIX ADDRESS FOR IVRTR
          IR = MINV-1+IVRTR+NSHIFT
C
C         LOOP OVER OCCUPIED STATES IOCCB AND VIRTUAL STATES IVRTS
          DO IOCCB=1,IOCCA
            DO IVRTS=1,NUMV
C
C             LIST ADDRESS FOR THIS IVRTS,IOCCB COMBINATION
              MSB = (IOCCB-1)*NUMV+IVRTS
C
C             LIST ADDRESS FOR THIS IOCCA AND THE ABOVE MSB
              MASB = (IOCCA-1)*NUMV*NUMO + MSB
C
C             LOOP OVER BASIS FUNCTIONS IN BLOCK B, CONTRACT OVER ASB2
              TEMP = DCMPLX(0.0D0,0.0D0)
C
              DO JBAS=1,NBAS(2)
C
C               (PA|SB) = (+A|SB) + (-A|SB)
                TEMP = TEMP + ASB2(JBAS,MASB,1)*DCONJG(C(NB1+JBAS,IR))
     &                      + ASB2(JBAS,MASB,2)*DCONJG(C(NB2+JBAS,IR))
C
              ENDDO
C
C             LIST ADDRESS FOR THIS IVRTR,IOCCA AND THE ABOVE MSB
              MRASB = (IOCCA-1)*NUMV*IOCCA*NUMV/2
     &              + (IVRTR-1)*NUMV*IOCCA + MSB
C
C             UPDATE RASB VALUE
              RASB(MRASB) = RASB(MRASB) + TEMP
C
            ENDDO
          ENDDO
        ENDDO
      ENDDO
C     CLOSE THE OPENMP PARALLEL REGION
CC$OMP END PARALLEL DO
C
5400  CONTINUE
C
      CALL CPU_TIME(T2)
      T2 = OMP_GET_WTIME()
      TCN4 = TCN4 + T2 - T1
C
C     ALL CONTRIBUTIONS FROM THIS CLASS (A,B,C,D) NOW ACCOUNTED FOR
C
4001  CONTINUE
4000  CONTINUE
3000  CONTINUE
2000  CONTINUE
1500  CONTINUE
C
C**********************************************************************C
C     CALCULATE SECOND-ORDER PAIR CORRELATION ENERGY                   C
C**********************************************************************C
C
      CALL CPU_TIME(T1)
C
C     FOR EACH IOCCA,IOCCB PAIR, SUM OVER IVRTR AND IVRTS CONTRIBUTIONS
C
C     LOOP OVER OCCUPIED STATES IOCCA AND VIRTUAL STATES IVRTR
      DO IOCCA=1,NUMO
        DO IVRTR=1,NUMV
C
C         FOCK MATRIX ADDRESSES
          IA = MINO-1+IOCCA+NSHIFT
          IR = MINV-1+IVRTR+NSHIFT
C
C         LOOP OVER OCCUPIED STATES IOCCB AND VIRTUAL STATES IVRTS
          DO IOCCB=1,IOCCA
            DO IVRTS=1,NUMV
C
C             FOCK MATRIX ADDRESSES
              IB = MINO-1+IOCCB+NSHIFT
              IS = MINV-1+IVRTS+NSHIFT
C
C             MAIN LIST ADDRESS FOR THIS IOCCA,IVRTR,IOCCB,IVRTS
              MRASB = (IOCCA-1)*NUMV*IOCCA*NUMV/2
     &              + (IVRTR-1)*NUMV*IOCCA + (IOCCB-1)*NUMV + IVRTS
C
C             MAIN LIST ADDRESS FOR THIS IOCCA,IVRTS,IOCCB,IVRTR
              MSARB = (IOCCA-1)*NUMV*IOCCA*NUMV/2
     &              + (IVRTS-1)*NUMV*IOCCA + (IOCCB-1)*NUMV + IVRTR
C
C             NUMERATOR FOR DIRECT AND EXCHANGE CONTRIBUTIONS
              RNUMD = DREAL(RASB(MRASB)*DCONJG(RASB(MRASB)))
              RNUMX =-DREAL(RASB(MRASB)*DCONJG(RASB(MSARB)))
C
C             DENOMINATOR FOR BOTH CONTRIBUTIONS
              EABRS = EIGEN(IA) + EIGEN(IB) - EIGEN(IR) - EIGEN(IS)
C
C             ADD TO DIRECT AND EXCHANGE BINS
              EAB2(IOCCA,IOCCB,4) = EAB2(IOCCA,IOCCB,4) + RNUMD/EABRS
              EAB2(IOCCA,IOCCB,5) = EAB2(IOCCA,IOCCB,5) + RNUMX/EABRS
C
            ENDDO
          ENDDO
        ENDDO
      ENDDO
C
C     FILL IN THE OTHER HALF OF THE ARRAY AND CALCULATE TOTALS
      E1T = 0.0D0
      E2D = 0.0D0
      E2X = 0.0D0
      E2S = 0.0D0
      DO IOCCA=1,NUMO
        DO IOCCB=1,IOCCA
C
C         INTERMEDIATE VALUES
          EAB1TOT = EAB2(IOCCA,IOCCB,3)
          EAB2DIR = EAB2(IOCCA,IOCCB,4)
          EAB2XCH = EAB2(IOCCA,IOCCB,5)
          EAB2SUM = EAB2DIR + EAB2XCH
C
C         PUT THESE INTO EAB2 AND ADD CONTRIBUTION TO E2
          EAB2(IOCCA,IOCCB,6) = EAB2SUM
          IF(IOCCA.NE.IOCCB) THEN
            EAB2(IOCCB,IOCCA,3) = EAB1TOT
            EAB2(IOCCB,IOCCA,4) = EAB2DIR
            EAB2(IOCCB,IOCCA,5) = EAB2XCH
            EAB2(IOCCB,IOCCA,6) = EAB2SUM
            E1T = E1T + 1.0D0*EAB1TOT
            E2D = E2D + 1.0D0*EAB2DIR
            E2X = E2X + 1.0D0*EAB2XCH
            E2S = E2S + 1.0D0*EAB2SUM
          ELSE
            E1T = E1T + 0.5D0*EAB1TOT
            E2D = E2D + 0.5D0*EAB2DIR
            E2X = E2X + 0.5D0*EAB2XCH
            E2S = E2S + 0.5D0*EAB2SUM
          ENDIF
        ENDDO
      ENDDO
C
C**********************************************************************C
C     CALCULATE SECOND-ORDER SINGLE ORBITAL ENERGY                     C
C**********************************************************************C
C
C     FOR EACH IOCCA, SUM OVER THE IOCCB CONTRIBUTIONS
      DO IOCCA=1,NUMO
        DO N=1,6
          EA2(IOCCA,N) = 0.0D0
          DO IOCCB=1,NUMO
            EA2(IOCCA,N) = EA2(IOCCA,N) + EAB2(IOCCA,IOCCB,N)
          ENDDO
        ENDDO
      ENDDO
C
      CALL CPU_TIME(T2)
      TSUM = TSUM + T2 - T1
C
C**********************************************************************C
C     TERMINAL OUTPUT SUMMARY                                          C
C**********************************************************************C
C
C     MBPT2 PAIRWISE SUMMARY
20    FORMAT(1X,A,10X,A,11X,A,11X,A,11X,A)
21    FORMAT(' (',I2,',',I2,')',3X,F13.7,5X,F11.7,5X,F11.7,4X,F13.7)
      WRITE(6, *) ' '
      WRITE(7, *) ' '
      WRITE(6, *) REPEAT(' ',25),'MBPT2 pairwise summary'
      WRITE(7, *) REPEAT(' ',25),'MBPT2 pairwise summary'
      WRITE(6, *) REPEAT('-',72)
      WRITE(7, *) REPEAT('-',72)
      WRITE(6,20) '( a, b)','E1(ab)','E2(J)','E2(K)','E2(ab)'
      WRITE(7,20) '( a, b)','E1(ab)','E2(J)','E2(K)','E2(ab)'
      WRITE(6, *) REPEAT('-',72)
      WRITE(7, *) REPEAT('-',72)
      DO IOCCA=1,NUMO
        IANUM = IOCCA+MINO-1
        DO IOCCB=1,IOCCA
          IBNUM = IOCCB+MINO-1
          WRITE(6,21) IANUM,IBNUM,0.0D0,(EAB2(IOCCA,IOCCB,N),N=4,6)
          WRITE(7,21) IANUM,IBNUM,0.0D0,(EAB2(IOCCA,IOCCB,N),N=4,6)
        ENDDO
      ENDDO
      WRITE(6, *) REPEAT('-',72)
      WRITE(7, *) REPEAT('-',72)
C
C     MBPT2 SINGLE-PARTICLE SUMMARY
30    FORMAT(1X,A,11X,A,11X,A,11X,A,11X,A)
31    FORMAT('  ',I2,'    ',3X,F13.7,5X,F11.7,5X,F11.7,4X,F13.7)

      WRITE(6, *) ' '
      WRITE(7, *) ' '
      WRITE(6, *) REPEAT(' ',20),'MBPT2 single particle summary'
      WRITE(7, *) REPEAT(' ',20),'MBPT2 single particle summary'
      WRITE(6, *) REPEAT('-',72)
      WRITE(7, *) REPEAT('-',72)
      WRITE(6,30) '  a    ','E1(a)','E2(J)','E2(K)',' E2(a)'
      WRITE(7,30) '  a    ','E1(a)','E2(J)','E2(K)',' E2(a)'
      WRITE(6, *) REPEAT('-',72)
      WRITE(7, *) REPEAT('-',72)
      DO IOCCA=1,NUMO
        IANUM = IOCCA+MINO-1
        WRITE(6,31) IANUM,(EA2(IOCCA,N),N=3,6)
        WRITE(7,31) IANUM,(EA2(IOCCA,N),N=3,6)
      ENDDO
      WRITE(6, *) REPEAT('-',72)
      WRITE(7, *) REPEAT('-',72)
C
C     MBPT2 TOTAL SECOND ORDER CORRELATION ENERGY
32    FORMAT(' total  ',3X,F13.7,5X,F11.7,5X,F11.7,4X,F13.7)

      WRITE(6, *) ' '
      WRITE(7, *) ' '
      WRITE(6, *) REPEAT(' ',20),'MBPT2 second order correlation energy'
      WRITE(7, *) REPEAT(' ',20),'MBPT2 second order correlation energy'
      WRITE(6, *) REPEAT('-',72)
      WRITE(7, *) REPEAT('-',72)
      WRITE(6,32) 0.0D0,E2D,E2X,E2S
      WRITE(7,32) 0.0D0,E2D,E2X,E2S
      WRITE(6, *) REPEAT('-',72)
      WRITE(7, *) REPEAT('-',72)
C
C     MBPT2 LABOUR ANALYSIS
      CALL CPU_TIME(TFIN)
      TTOT = TFIN - TBEG
      TOTH = TTOT - (TERI + TCN1 + TCN2 + TCN3 + TCN4 + TSUM)

40    FORMAT(1X,A,24X,A)
      WRITE(6, *) REPEAT(' ',72)
      WRITE(7, *) REPEAT(' ',72)
      WRITE(6, *) REPEAT('=',72)
      WRITE(7, *) REPEAT('=',72)
      WRITE(6, *) REPEAT(' ',26),'MBPT2 labour analysis'
      WRITE(7, *) REPEAT(' ',26),'MBPT2 labour analysis'
      WRITE(6, *) REPEAT('=',72)
      WRITE(7, *) REPEAT('=',72)
C
      WRITE(6,40) 'ERI construction - (IJ|KL)      ',HMS(TERI)
      WRITE(7,40) 'ERI construction - (IJ|KL)      ',HMS(TERI)
      WRITE(6,40) '1st contraction  - (IJ|KB)      ',HMS(TCN1)
      WRITE(7,40) '1st contraction  - (IJ|KB)      ',HMS(TCN1)
      WRITE(6,40) '2nd contraction  - (IJ|SB)      ',HMS(TCN2)
      WRITE(7,40) '2nd contraction  - (IJ|SB)      ',HMS(TCN2)
      WRITE(6,40) '3rd contraction  - (IA|SB)      ',HMS(TCN3)
      WRITE(7,40) '3rd contraction  - (IA|SB)      ',HMS(TCN3)
      WRITE(6,40) '4th contraction  - (RA|SB)      ',HMS(TCN4)
      WRITE(7,40) '4th contraction  - (RA|SB)      ',HMS(TCN4)
      WRITE(6,40) 'Virtual orbital sum - E2(A,B)   ',HMS(TSUM)
      WRITE(7,40) 'Virtual orbital sum - E2(A,B)   ',HMS(TSUM)
      WRITE(6,40) 'Other                           ',HMS(TOTH)
      WRITE(7,40) 'Other                           ',HMS(TOTH)
      WRITE(6, *) REPEAT('-',72)
      WRITE(7, *) REPEAT('-',72)
      WRITE(6,40) 'Total MBPT2 time                ',HMS(TTOT)
      WRITE(7,40) 'Total MBPT2 time                ',HMS(TTOT)
      WRITE(6, *) REPEAT('=',72)
      WRITE(7, *) REPEAT('=',72)
C
      RETURN
      END

