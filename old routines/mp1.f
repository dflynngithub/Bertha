      SUBROUTINE MP1
      IMPLICIT DOUBLE PRECISION (A-H,O-Z)
C**********************************************************************C
C                                                                      C
C                       MM       MM PPPPPPP   11                       C
C                       MMM     MMM PP    PP 111                       C
C                       MMMM   MMMM PP    PP  11                       C
C                       MM MM MM MM PP    PP  11                       C
C                       MM  MMM  MM PPPPPPP   11                       C
C                       MM   M   MM PP        11                       C
C                       MM       MM PP       1111                      C
C                                                                      C
C -------------------------------------------------------------------- C
C  MP1 EVALUATES ZERO AND FIRST ORDER ENERGIES FOR ALL OCCUPIED        C
C  SOLUTIONS TO A CONVERGED HARTREE-FOCK PROBLEM.                      C
C**********************************************************************C
      PARAMETER(MDM=1200,MBS=26,MB2=MBS*MBS,MCT=15,MKP=9,MFL=7000000)
C
      CHARACTER*4  HMLTN
      CHARACTER*8  SHAPE
      CHARACTER*16 HMS
      CHARACTER*40 MOLCL,WFNFL,OUTFL
C
      DIMENSION EXPT(MBS,4),XYZ(3,4),KQN(4),MQN(4),NBAS(4),LQN(4),ITN(2)
      DIMENSION ISCF(11,6),IFLG(11),ISCR(11)
      DIMENSION INDEX(MCT,-(MKP+1)/2:(MKP+1)/2,MKP),ICNT(4)
C
      COMPLEX*16 ETMP1,ETMP2,ETMP3,ETMP4
      COMPLEX*16 RR(MB2,16)
      COMPLEX*16 C(MDM,MDM)
      COMPLEX*16 DENC(MDM,MDM),DENO(MDM,MDM),DENT(MDM,MDM)
      COMPLEX*16 OVAP(MDM,MDM),HNUC(MDM,MDM),HKIN(MDM,MDM),
     &           VUEH(MDM,MDM),GDIR(MDM,MDM),GXCH(MDM,MDM),
     &           QDIR(MDM,MDM),QXCH(MDM,MDM),BDIR(MDM,MDM),
     &           BXCH(MDM,MDM),FOCK(MDM,MDM)
C
      COMMON/COEF/C
      COMMON/DENS/DENC,DENO,DENT
      COMMON/E0LL/E0LLFL(MFL,8),IAD0LL(MCT,MCT,MKP,MKP,MKP,MKP)
      COMMON/E0SS/E0SSFL(MFL,8),IAD0SS(MCT,MCT,MKP,MKP,MKP,MKP)
      COMMON/IQTT/IABLL,ICDLL,IABSS,ICDSS,IABLS,ICDLS
      COMMON/ENRG/ETOT,ENUC,EONE,ECLG,ECLQ,EBRG,EBRQ,EHNC,EHKN,EGDR,
     &            EGXC,EQDR,EQXC,EBDR,EBXC,EMDR,EMXC,EUEH
      COMMON/FLNM/MOLCL,WFNFL,OUTFL
      COMMON/GEOM/SHAPE
      COMMON/MAKE/IEAB,IECD,IRIJ(MBS,MBS)
      COMMON/MTRX/OVAP,HNUC,HKIN,VUEH,GDIR,GXCH,QDIR,QXCH,BDIR,BXCH,FOCK
      COMMON/PRMS/CV,HMLTN,ITREE,IMOL,INEW,IEQS,IERC,IPAR,ICOR,ILEV
      COMMON/QNMS/LABICN(MDM),LABKQN(MDM),LABMQN(MDM)
      COMMON/SCRN/F2ES(5,7),T2ES(5,7),N2EB(5,7),N2ET(5,7),N2ES(5,7)
      COMMON/SPEC/EXPSET(MBS,MKP,MCT),COORD(3,MCT),ZNUC(MCT),AMASS(MCT),
     &            CNUC(MCT),PNUC,LARGE(MCT,MKP,MKP+1),NFUNCT(MKP,MCT),
     &            KVALS(MKP,MCT),IZNUC(MCT),IQNUC(MCT),LMAX(MCT),
     &            NKAP(MCT),NCNT,NDIM,NSHIFT,NOCC,NVRT
      COMMON/TMMD/TELL,TESS,TELS,TRLL,TRSS,TRLS,TRBR
C
      DIMENSION EAB1(NOCC,NOCC,6),EA1(NOCC,6)
C
      DATA SENS/1.0D-12/
C
      DATA ISCF/1,1,1,1,1,1,1,1,0,0,0,
     &          1,1,0,0,1,1,1,0,0,0,0,
     &          1,0,1,1,1,0,1,0,0,0,0,
     &          1,1,1,0,1,1,0,0,0,0,0,
     &          1,0,1,0,1,0,0,0,0,0,0,
     &          1,0,0,0,1,0,0,0,0,0,0/
C
C     LINEAR MOLECULE SHORTCUT OPTION
      IF(SHAPE.EQ.'DIATOMIC'.OR.SHAPE.EQ.'LINEAR') THEN
        ILIN = 1
      ELSE
        ILIN = 0
      ENDIF
C
C     SAVED BATCHES OF R(AB|CD) INTEGRALS IN ERI
      IF(IEQS.EQ.0) THEN
        IERC = 0
      ELSE
        IERC = 1
      ENDIF
C
      CALL CPU_TIME(TDM1)
C
C     INITIALISE ENERGY COUNTERS
      DO N=1,6
        DO IOCCB=1,NOCC
          EA1(IOCCB,N) = 0.0D0
          DO IOCCA=1,NOCC
            EAB1(IOCCA,IOCCB,N) = 0.0D0
          ENDDO
        ENDDO
      ENDDO
C
C     CONSTRUCT ORDERED INDEX SYSTEM FOR ALL POSSIBLE {XYZ,KQN,MQN}
      ICOUNT = 0
C
C     LOOP OVER ATOMIC CENTERS
      DO IC=1,NCNT
C
C       LOOP OVER KAPPA VALUES FOR THIS ATOMIC CENTER
        DO KN=1,NKAP(IC)
C
C         IMPORT KAPPA, MAXIMUM MQN
          KAPPA = KVALS(KN,IC)
          MJMAX = 2*IABS(KAPPA)-1
C
C         LOOP OVER MQN VALUES AND RECORD INDEX
          DO MJ=1,MJMAX,2
            ICOUNT = ICOUNT+1
            INDEX(IC,KAPPA,MJ) = ICOUNT
          ENDDO
        ENDDO
      ENDDO
C
C**********************************************************************C
C     ONE-BODY ENERGIES                                                C
C**********************************************************************C
C
C     CALCULATE ONE-BODY MATRIX REPS
      CALL ONEEL
C
C     LOOP OVER ALL OCCUPIED SPINOR PAIRS
      DO IOCCA=1,NOCC
        DO IOCCB=1,IOCCA
C
          IA = IOCCA + NSHIFT
          IB = IOCCB + NSHIFT
C
C         ONE-BODY ENERGY
          ETMP1 = DCMPLX(0.0D0,0.0D0)
          ETMP2 = DCMPLX(0.0D0,0.0D0)
          IF(IOCCA.EQ.IOCCB) THEN
            DO J=1,NDIM
              DO I=1,NDIM
                ETMP1 = ETMP1 + DCONJG(C(I,IA))*C(J,IB)*HNUC(I,J)
                ETMP2 = ETMP2 + DCONJG(C(I,IA))*C(J,IB)*HKIN(I,J)
              ENDDO
            ENDDO
          ENDIF
C
C         ADD RESULTS TO AN ARRAY FOR USE LATER
          EAB1(IOCCA,IOCCB,1) = DREAL(ETMP1)
          EAB1(IOCCA,IOCCB,2) = DREAL(ETMP2)
          EAB1(IOCCA,IOCCB,3) = DREAL(ETMP1 + ETMP2)
C
        ENDDO
      ENDDO
C
C**********************************************************************C
C     TWO-BODY ENERGIES                                                C
C**********************************************************************C
C
C
C**********************************************************************C
C     LOOP OVER COMPONENT OVERLAP OPTIONS (INDEX 1000)                 C
C**********************************************************************C
C
C     COMPONENT OVERLAP LABELS TO LOOP OVER
      IF(HMLTN.EQ.'BARE') THEN
        RETURN
      ELSEIF(HMLTN.EQ.'NORL') THEN
        ITSTRT = 1
        ITSTOP = 1
        ITSKIP = 1
      ELSE
        ITSTRT = 1
        ITSTOP = 4
        ITSKIP = 3
      ENDIF
C
C     LOOP OVER COMPONENT LABEL FOR A AND B: TT = LL (1) or SS (4)
      DO 1000 IT1=ITSTRT,ITSTOP,ITSKIP
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
      DO 1000 IT2=ITSTRT,ITSTOP,ITSKIP
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
        ICNT(1) = ICNTA
C
C       CARTESIAN COORDINATES OF CENTER A
        XYZ(1,1) = COORD(1,ICNTA)
        XYZ(2,1) = COORD(2,ICNTA)
        XYZ(3,1) = COORD(3,ICNTA)
C
C     LOOP OVER CENTER B
      DO 2000 ICNTB=1,ICNTA
        ICNT(2) = ICNTB
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
        ICNT(3) = ICNTC
C
C       CARTESIAN COORDINATES OF CENTER C
        XYZ(1,3) = COORD(1,ICNTC)
        XYZ(2,3) = COORD(2,ICNTC)
        XYZ(3,3) = COORD(3,ICNTC)
C
C     LOOP OVER CENTER D
      DO 3000 ICNTD=1,NCNT
        ICNT(4) = ICNTD
C
C       CARTESIAN COORDINATES OF CENTER D
        XYZ(1,4) = COORD(1,ICNTD)
        XYZ(2,4) = COORD(2,ICNTD)
        XYZ(3,4) = COORD(3,ICNTD)
C
C     NUMBER OF NUCLEAR CENTERS INVOLVED IN THIS OVERLAP
      MCNT = NCNTRS(ICNTA,ICNTB,ICNTC,ICNTD)
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
C     MOLECULAR SELECTION RULES BASED ON XYZ, KQN AND LQN              C
C**********************************************************************C
C
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
C     MOLECULAR SELECTION RULES BASED ON MQN                           C
C**********************************************************************C
C
C     SPIN PROJECTION CONSERVED ALONG Z-AXIS
      IF(ILIN.EQ.1) THEN
        IF(MQN(1).EQ.MQN(2).AND.MQN(3).EQ.MQN(4)) GOTO 5503
        IF(MQN(1).EQ.MQN(3).AND.MQN(2).EQ.MQN(4)) GOTO 5503
        IF(MQN(1).EQ.MQN(4).AND.MQN(2).EQ.MQN(3)) GOTO 5503
        GOTO 4001
      ENDIF
5503  CONTINUE
C
C**********************************************************************C
C     INDEX ASSIGNMENT AND IDENTIFICATION OF ERI SYMMETRY CLASSES      C
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
      IF(IQ1.LT.IQ2) GOTO 4001
      IF(IQ3.LT.IQ4) GOTO 4001
      IF(IQL.LT.IQR) GOTO 4001
C
      IF(IQ1.GT.IQ2) THEN
C       IQ1 > IQ2
        IF(IQ3.GT.IQ4) THEN
C         IQ3 > IQ4
          IF(IQL.GT.IQR) THEN
C           IQL > IQR
            ITSCF = 1
          ELSEIF(IQL.EQ.IQR) THEN
C           IQL = IQR
            ITSCF = 2
          ENDIF
        ELSEIF(IQ3.EQ.IQ4) THEN
C         IQ3 = IQ4
          IF(IQL.GT.IQR) THEN
C           IQL > IQR
            ITSCF = 3
          ELSE
C           IQL = IQR
            GOTO 4001
          ENDIF
        ENDIF
      ELSEIF(IQ1.EQ.IQ2) THEN
C       IQ1 = IQ2
        IF(IQ3.GT.IQ4) THEN
C         IQ3 > IQ4
          IF(IQL.GT.IQR) THEN
C           IQL > IQR
            ITSCF = 4
          ELSE
C           IQL = IQR
            GOTO 4001
          ENDIF
        ELSEIF(IQ3.EQ.IQ4) THEN
C         IQ3 = IQ4
          IF(IQL.GT.IQR) THEN
C           IQL > IQR
            ITSCF = 5
          ELSEIF(IQL.EQ.IQR) THEN
C           IQL = IQR
            ITSCF = 6
          ENDIF
        ENDIF
      ENDIF
C
C     READ IN FLAG VALUES FROM ISCF DATA BLOCK
      DO N=1,11
        IFLG(N) = ISCF(N,ITSCF)
      ENDDO
C
C     INCLUDE SPECIAL CASES FOR MATCHING BLOCKS
      IF(ITSCF.EQ.1) THEN
        IF(IQ1.EQ.IQ3) THEN
C         IQ1 = IQ3
          IFLG(10) = 1
        ENDIF
        IF(IQ2.EQ.IQ4) THEN
C         IQ2 = IQ3
          IFLG(11) = 1
        ENDIF
        IF(IQ2.EQ.IQ3) THEN
C         IQ2 = IQ3
          IFLG( 9) = 1
        ENDIF
      ELSEIF(ITSCF.EQ.3) THEN
        IF(IQ2.EQ.IQ3) THEN
C         IQ2 = IQ3
          IFLG( 9) = 1
        ENDIF
      ELSEIF(ITSCF.EQ.4) THEN
        IF(IQ2.EQ.IQ3) THEN
C         IQ2 = IQ3
          IFLG( 9) = 1
        ENDIF
      ENDIF
C
C     UPDATE COUNTER FOR NUMBER OF CLASSES
      N2EB(MCNT,ITT) = N2EB(MCNT,ITT) + 1
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
C**********************************************************************C
C     LOOP OVER BASIS FUNCTIONS IN BLOCKS A AND B (INDEX 5000)         C
C**********************************************************************C
C
C     LOOP OVER ELEMENTS OF FOCK MATRIX BLOCK
      DO 5000 IBAS=1,NBAS(1)
      DO 5000 JBAS=1,NBAS(2)
C
C     UPDATE COUNTER FOR NUMBER OF BATCHES
      N2ET(MCNT,ITT) = N2ET(MCNT,ITT)+1
C
C     GENERATE BATCH OF ELECTRON REPULSION INTEGRALS
      CALL ERI(RR,XYZ,KQN,MQN,EXPT,NBAS,ITN,IBAS,JBAS)
C
C**********************************************************************C
C     LOOP OVER OCCUPIED ORBITALS IOCCA AND IOCCB (INDEX 6000 + 7000)  C
C**********************************************************************C
C
      DO 6000 IOCCB=1,IOCCA
        IB = IOCCB + NSHIFT
C
C     THE DIRECT AND EXCHANGE CONTRIBUTIONS TO GMAT ARE CALCULATED WITH
C     USE OF INTEGRAL SYMMETRY BY PERMUTATION OF MQNS -- DECISIONS BASED
C     ON THE CURRENT MQN COMBINATION TELL US WHICH BATCHES TO USE.
C
C     1ST CASE (DIRECT)
      IF(IFLG(1).EQ.1) THEN
        M = 0
        DO KBAS=1,NBAS(3)
          DO LBAS=1,NBAS(4)
            M = M+1
C
            ETMP3 = ETMP3
     &       +           RR(M, 1)*DCONJG(C(NC1+KBAS,IB))*C(ND1+LBAS,IB)
     &       +           RR(M, 2)*DCONJG(C(NC1+KBAS,IB))*C(ND2+LBAS,IB)
     &       +           RR(M, 3)*DCONJG(C(NC2+KBAS,IB))*C(ND1+LBAS,IB)
     &       +           RR(M, 4)*DCONJG(C(NC2+KBAS,IB))*C(ND2+LBAS,IB)
C
            ETMP3 = ETMP3
     &       +           RR(M, 5)*DCONJG(C(NC1+KBAS,IB))*C(ND1+LBAS,IB)
     &       +           RR(M, 6)*DCONJG(C(NC1+KBAS,IB))*C(ND2+LBAS,IB)
     &       +           RR(M, 7)*DCONJG(C(NC2+KBAS,IB))*C(ND1+LBAS,IB)
     &       +           RR(M, 8)*DCONJG(C(NC2+KBAS,IB))*C(ND2+LBAS,IB)
C
            ETMP3 = ETMP3
     &       +           RR(M, 9)*DCONJG(C(NC1+KBAS,IB))*C(ND1+LBAS,IB)
     &       +           RR(M,10)*DCONJG(C(NC1+KBAS,IB))*C(ND2+LBAS,IB)
     &       +           RR(M,11)*DCONJG(C(NC2+KBAS,IB))*C(ND1+LBAS,IB)
     &       +           RR(M,12)*DCONJG(C(NC2+KBAS,IB))*C(ND2+LBAS,IB)
C
            ETMP3 = ETMP3
     &       +           RR(M,13)*DCONJG(C(NC1+KBAS,IB))*C(ND1+LBAS,IB)
     &       +           RR(M,14)*DCONJG(C(NC1+KBAS,IB))*C(ND2+LBAS,IB)
     &       +           RR(M,15)*DCONJG(C(NC2+KBAS,IB))*C(ND1+LBAS,IB)
     &       +           RR(M,16)*DCONJG(C(NC2+KBAS,IB))*C(ND2+LBAS,IB)
C
          ENDDO
        ENDDO
      ENDIF
C
C     2ND CASE (DIRECT)
      IF(IFLG(2).EQ.1) THEN
        M = 0
        DO KBAS=1,NBAS(3)
          DO LBAS=1,NBAS(4)
            M = M+1
C
            ETMP3 = ETMP3
     &       +      PCD1*RR(M, 4)*DCONJG(C(ND1+LBAS,IB))*C(NC1+KBAS,IB)
     &       +      PCD2*RR(M, 2)*DCONJG(C(ND1+LBAS,IB))*C(NC2+KBAS,IB)
     &       +      PCD2*RR(M, 3)*DCONJG(C(ND2+LBAS,IB))*C(NC1+KBAS,IB)
     &       +      PCD1*RR(M, 1)*DCONJG(C(ND2+LBAS,IB))*C(NC2+KBAS,IB)
C
            ETMP3 = ETMP3
     &       +      PCD1*RR(M, 8)*DCONJG(C(ND1+LBAS,IB))*C(NC1+KBAS,IB)
     &       +      PCD2*RR(M, 6)*DCONJG(C(ND1+LBAS,IB))*C(NC2+KBAS,IB)
     &       +      PCD2*RR(M, 7)*DCONJG(C(ND2+LBAS,IB))*C(NC1+KBAS,IB)
     &       +      PCD1*RR(M, 5)*DCONJG(C(ND2+LBAS,IB))*C(NC2+KBAS,IB)
C
            ETMP3 = ETMP3
     &       +      PCD1*RR(M,12)*DCONJG(C(ND1+LBAS,IB))*C(NC1+KBAS,IB)
     &       +      PCD2*RR(M,10)*DCONJG(C(ND1+LBAS,IB))*C(NC2+KBAS,IB)
     &       +      PCD2*RR(M,11)*DCONJG(C(ND2+LBAS,IB))*C(NC1+KBAS,IB)
     &       +      PCD1*RR(M, 9)*DCONJG(C(ND2+LBAS,IB))*C(NC2+KBAS,IB)
C
            ETMP3 = ETMP3
     &       +      PCD1*RR(M,16)*DCONJG(C(ND1+LBAS,IB))*C(NC1+KBAS,IB)
     &       +      PCD2*RR(M,14)*DCONJG(C(ND1+LBAS,IB))*C(NC2+KBAS,IB)
     &       +      PCD2*RR(M,15)*DCONJG(C(ND2+LBAS,IB))*C(NC1+KBAS,IB)
     &       +      PCD1*RR(M,13)*DCONJG(C(ND2+LBAS,IB))*C(NC2+KBAS,IB)
C
          ENDDO
        ENDDO
      ENDIF
C
C     3RD CASE (DIRECT)
      IF(IFLG(3).EQ.1) THEN
        M = 0
        DO KBAS=1,NBAS(3)
          DO LBAS=1,NBAS(4)
            M = M+1
C
            ETMP3 = ETMP3
     &       +           RR(M, 1)*DCONJG(C(NA1+IBAS,IB))*C(NB1+JBAS,IB)
     &       +           RR(M, 5)*DCONJG(C(NA1+IBAS,IB))*C(NB2+JBAS,IB)
     &       +           RR(M, 9)*DCONJG(C(NA2+IBAS,IB))*C(NB1+JBAS,IB)
     &       +           RR(M,13)*DCONJG(C(NA2+IBAS,IB))*C(NB2+JBAS,IB)
C
            ETMP3 = ETMP3
     &       +           RR(M, 2)*DCONJG(C(NA1+IBAS,IB))*C(NB1+JBAS,IB)
     &       +           RR(M, 6)*DCONJG(C(NA1+IBAS,IB))*C(NB2+JBAS,IB)
     &       +           RR(M,10)*DCONJG(C(NA2+IBAS,IB))*C(NB1+JBAS,IB)
     &       +           RR(M,14)*DCONJG(C(NA2+IBAS,IB))*C(NB2+JBAS,IB)
C
            ETMP3 = ETMP3
     &       +           RR(M, 3)*DCONJG(C(NA1+IBAS,IB))*C(NB1+JBAS,IB)
     &       +           RR(M, 7)*DCONJG(C(NA1+IBAS,IB))*C(NB2+JBAS,IB)
     &       +           RR(M,11)*DCONJG(C(NA2+IBAS,IB))*C(NB1+JBAS,IB)
     &       +           RR(M,15)*DCONJG(C(NA2+IBAS,IB))*C(NB2+JBAS,IB)
C
            ETMP3 = ETMP3
     &       +           RR(M, 4)*DCONJG(C(NA1+IBAS,IB))*C(NB1+JBAS,IB)
     &       +           RR(M, 8)*DCONJG(C(NA1+IBAS,IB))*C(NB2+JBAS,IB)
     &       +           RR(M,12)*DCONJG(C(NA2+IBAS,IB))*C(NB1+JBAS,IB)
     &       +           RR(M,16)*DCONJG(C(NA2+IBAS,IB))*C(NB2+JBAS,IB)
C
          ENDDO
        ENDDO
      ENDIF
C
C     4TH CASE (DIRECT)
      IF(IFLG(4).EQ.1) THEN
        M = 0
        DO KBAS=1,NBAS(3)
          DO LBAS=1,NBAS(4)
            M = M+1
C
            ETMP3 = ETMP3
     &       +      PAB1*RR(M,13)*DCONJG(C(NB1+JBAS,IB))*C(NA1+IBAS,IB)
     &       +      PAB2*RR(M, 5)*DCONJG(C(NB1+JBAS,IB))*C(NA2+IBAS,IB)
     &       +      PAB2*RR(M, 9)*DCONJG(C(NB2+JBAS,IB))*C(NA1+IBAS,IB)
     &       +      PAB1*RR(M, 1)*DCONJG(C(NB2+JBAS,IB))*C(NA2+IBAS,IB)
C
            ETMP3 = ETMP3
     &       +      PAB1*RR(M,14)*DCONJG(C(NB1+JBAS,IB))*C(NA1+IBAS,IB)
     &       +      PAB2*RR(M, 6)*DCONJG(C(NB1+JBAS,IB))*C(NA2+IBAS,IB)
     &       +      PAB2*RR(M,10)*DCONJG(C(NB2+JBAS,IB))*C(NA1+IBAS,IB)
     &       +      PAB1*RR(M, 2)*DCONJG(C(NB2+JBAS,IB))*C(NA2+IBAS,IB)
C
            ETMP3 = ETMP3
     &       +      PAB1*RR(M,15)*DCONJG(C(NB1+JBAS,IB))*C(NA1+IBAS,IB)
     &       +      PAB2*RR(M, 7)*DCONJG(C(NB1+JBAS,IB))*C(NA2+IBAS,IB)
     &       +      PAB2*RR(M,11)*DCONJG(C(NB2+JBAS,IB))*C(NA1+IBAS,IB)
     &       +      PAB1*RR(M, 3)*DCONJG(C(NB2+JBAS,IB))*C(NA2+IBAS,IB)
C
            ETMP3 = ETMP3
     &       +      PAB1*RR(M,16)*DCONJG(C(NB1+JBAS,IB))*C(NA1+IBAS,IB)
     &       +      PAB2*RR(M, 8)*DCONJG(C(NB1+JBAS,IB))*C(NA2+IBAS,IB)
     &       +      PAB2*RR(M,12)*DCONJG(C(NB2+JBAS,IB))*C(NA1+IBAS,IB)
     &       +      PAB1*RR(M, 4)*DCONJG(C(NB2+JBAS,IB))*C(NA2+IBAS,IB)
C
          ENDDO
        ENDDO
      ENDIF
C
C     5TH CASE (EXCHANGE)
      IF(IFLG(5).EQ.1) THEN
        M = 0
        DO KBAS=1,NBAS(3)
          DO LBAS=1,NBAS(4)
            M = M+1
C
            ETMP4 = ETMP4
     &       +           RR(M, 1)*DCONJG(C(NC1+KBAS,IB))*C(NB1+JBAS,IB)
     &       +           RR(M, 5)*DCONJG(C(NC1+KBAS,IB))*C(NB2+JBAS,IB)
     &       +           RR(M, 3)*DCONJG(C(NC2+KBAS,IB))*C(NB1+JBAS,IB)
     &       +           RR(M, 7)*DCONJG(C(NC2+KBAS,IB))*C(NB2+JBAS,IB)
C
            ETMP4 = ETMP4
     &       +           RR(M, 2)*DCONJG(C(NC1+KBAS,IB))*C(NB1+JBAS,IB)
     &       +           RR(M, 6)*DCONJG(C(NC1+KBAS,IB))*C(NB2+JBAS,IB)
     &       +           RR(M, 4)*DCONJG(C(NC2+KBAS,IB))*C(NB1+JBAS,IB)
     &       +           RR(M, 8)*DCONJG(C(NC2+KBAS,IB))*C(NB2+JBAS,IB)
C
            ETMP4 = ETMP4
     &       +           RR(M, 9)*DCONJG(C(NC1+KBAS,IB))*C(NB1+JBAS,IB)
     &       +           RR(M,13)*DCONJG(C(NC1+KBAS,IB))*C(NB2+JBAS,IB)
     &       +           RR(M,11)*DCONJG(C(NC2+KBAS,IB))*C(NB1+JBAS,IB)
     &       +           RR(M,15)*DCONJG(C(NC2+KBAS,IB))*C(NB2+JBAS,IB)
C
            ETMP4 = ETMP4
     &       +           RR(M,10)*DCONJG(C(NC1+KBAS,IB))*C(NB1+JBAS,IB)
     &       +           RR(M,14)*DCONJG(C(NC1+KBAS,IB))*C(NB2+JBAS,IB)
     &       +           RR(M,12)*DCONJG(C(NC2+KBAS,IB))*C(NB1+JBAS,IB)
     &       +           RR(M,16)*DCONJG(C(NC2+KBAS,IB))*C(NB2+JBAS,IB)
C
          ENDDO
        ENDDO
      ENDIF
C
C     6TH CASE (EXCHANGE)
      IF(IFLG(6).EQ.1) THEN
        M = 0
        DO KBAS=1,NBAS(3)
          DO LBAS=1,NBAS(4)
            M = M+1
C
            ETMP4 = ETMP4
     &       +      PCD1*RR(M, 4)*DCONJG(C(ND1+LBAS,IB))*C(NB1+JBAS,IB)
     &       +      PCD1*RR(M, 8)*DCONJG(C(ND1+LBAS,IB))*C(NB2+JBAS,IB)
     &       +      PCD2*RR(M, 3)*DCONJG(C(ND2+LBAS,IB))*C(NB1+JBAS,IB)
     &       +      PCD2*RR(M, 7)*DCONJG(C(ND2+LBAS,IB))*C(NB2+JBAS,IB)
C
            ETMP4 = ETMP4
     &       +      PCD2*RR(M, 2)*DCONJG(C(ND1+LBAS,IB))*C(NB1+JBAS,IB)
     &       +      PCD2*RR(M, 6)*DCONJG(C(ND1+LBAS,IB))*C(NB2+JBAS,IB)
     &       +      PCD1*RR(M, 1)*DCONJG(C(ND2+LBAS,IB))*C(NB1+JBAS,IB)
     &       +      PCD1*RR(M, 5)*DCONJG(C(ND2+LBAS,IB))*C(NB2+JBAS,IB)
C
            ETMP4 = ETMP4
     &       +      PCD1*RR(M,12)*DCONJG(C(ND1+LBAS,IB))*C(NB1+JBAS,IB)
     &       +      PCD1*RR(M,16)*DCONJG(C(ND1+LBAS,IB))*C(NB2+JBAS,IB)
     &       +      PCD2*RR(M,11)*DCONJG(C(ND2+LBAS,IB))*C(NB1+JBAS,IB)
     &       +      PCD2*RR(M,15)*DCONJG(C(ND2+LBAS,IB))*C(NB2+JBAS,IB)
C
            ETMP4 = ETMP4
     &       +      PCD2*RR(M,10)*DCONJG(C(ND1+LBAS,IB))*C(NB1+JBAS,IB)
     &       +      PCD2*RR(M,14)*DCONJG(C(ND1+LBAS,IB))*C(NB2+JBAS,IB)
     &       +      PCD1*RR(M, 9)*DCONJG(C(ND2+LBAS,IB))*C(NB1+JBAS,IB)
     &       +      PCD1*RR(M,13)*DCONJG(C(ND2+LBAS,IB))*C(NB2+JBAS,IB)
C
          ENDDO
        ENDDO
      ENDIF
C
C     7TH CASE (EXCHANGE)
      IF(IFLG(7).EQ.1) THEN
        M = 0
        DO KBAS=1,NBAS(3)
          DO LBAS=1,NBAS(4)
            M = M+1
C
            ETMP4 = ETMP4
     &       +      PAB1*RR(M,13)*DCONJG(C(NC1+KBAS,IB))*C(NA1+IBAS,IB)
     &       +      PAB2*RR(M, 5)*DCONJG(C(NC1+KBAS,IB))*C(NA2+IBAS,IB)
     &       +      PAB1*RR(M,15)*DCONJG(C(NC2+KBAS,IB))*C(NA1+IBAS,IB)
     &       +      PAB2*RR(M, 7)*DCONJG(C(NC2+KBAS,IB))*C(NA2+IBAS,IB)
C
            ETMP4 = ETMP4
     &       +      PAB1*RR(M,14)*DCONJG(C(NC1+KBAS,IB))*C(NA1+IBAS,IB)
     &       +      PAB2*RR(M, 6)*DCONJG(C(NC1+KBAS,IB))*C(NA2+IBAS,IB)
     &       +      PAB1*RR(M,16)*DCONJG(C(NC2+KBAS,IB))*C(NA1+IBAS,IB)
     &       +      PAB2*RR(M, 8)*DCONJG(C(NC2+KBAS,IB))*C(NA2+IBAS,IB)
C
            ETMP4 = ETMP4
     &       +      PAB2*RR(M, 9)*DCONJG(C(NC1+KBAS,IB))*C(NA1+IBAS,IB)
     &       +      PAB1*RR(M, 1)*DCONJG(C(NC1+KBAS,IB))*C(NA2+IBAS,IB)
     &       +      PAB2*RR(M,11)*DCONJG(C(NC2+KBAS,IB))*C(NA1+IBAS,IB)
     &       +      PAB1*RR(M, 3)*DCONJG(C(NC2+KBAS,IB))*C(NA2+IBAS,IB)
C
            ETMP4 = ETMP4
     &       +      PAB2*RR(M,10)*DCONJG(C(NC1+KBAS,IB))*C(NA1+IBAS,IB)
     &       +      PAB1*RR(M, 2)*DCONJG(C(NC1+KBAS,IB))*C(NA2+IBAS,IB)
     &       +      PAB2*RR(M,12)*DCONJG(C(NC2+KBAS,IB))*C(NA1+IBAS,IB)
     &       +      PAB1*RR(M, 4)*DCONJG(C(NC2+KBAS,IB))*C(NA2+IBAS,IB)
C
          ENDDO
        ENDDO
      ENDIF
C
C     8TH CASE (EXCHANGE)
      IF(IFLG(8).EQ.1) THEN
        M = 0
        DO KBAS=1,NBAS(3)
          DO LBAS=1,NBAS(4)
            M = M+1
C
            ETMP4 = ETMP4
     &       + PAB1*PCD1*RR(M,16)*DCONJG(C(ND1+LBAS,IB))*C(NA1+IBAS,IB)
     &       + PAB2*PCD1*RR(M, 8)*DCONJG(C(ND1+LBAS,IB))*C(NA2+IBAS,IB)
     &       + PAB1*PCD2*RR(M,15)*DCONJG(C(ND2+LBAS,IB))*C(NA1+IBAS,IB)
     &       + PAB2*PCD2*RR(M, 7)*DCONJG(C(ND2+LBAS,IB))*C(NA2+IBAS,IB)
C
            ETMP4 = ETMP4
     &       + PAB1*PCD2*RR(M,14)*DCONJG(C(ND1+LBAS,IB))*C(NA1+IBAS,IB)
     &       + PAB2*PCD2*RR(M, 6)*DCONJG(C(ND1+LBAS,IB))*C(NA2+IBAS,IB)
     &       + PAB1*PCD1*RR(M,13)*DCONJG(C(ND2+LBAS,IB))*C(NA1+IBAS,IB)
     &       + PAB2*PCD1*RR(M, 5)*DCONJG(C(ND2+LBAS,IB))*C(NA2+IBAS,IB)
C
            ETMP4 = ETMP4
     &       + PAB2*PCD1*RR(M,12)*DCONJG(C(ND1+LBAS,IB))*C(NA1+IBAS,IB)
     &       + PAB1*PCD1*RR(M, 4)*DCONJG(C(ND1+LBAS,IB))*C(NA2+IBAS,IB)
     &       + PAB2*PCD2*RR(M,11)*DCONJG(C(ND2+LBAS,IB))*C(NA1+IBAS,IB)
     &       + PAB1*PCD2*RR(M, 3)*DCONJG(C(ND2+LBAS,IB))*C(NA2+IBAS,IB)
C
            ETMP4 = ETMP4
     &       + PAB2*PCD2*RR(M,10)*DCONJG(C(ND1+LBAS,IB))*C(NA1+IBAS,IB)
     &       + PAB1*PCD2*RR(M, 2)*DCONJG(C(ND1+LBAS,IB))*C(NA2+IBAS,IB)
     &       + PAB2*PCD1*RR(M, 9)*DCONJG(C(ND2+LBAS,IB))*C(NA1+IBAS,IB)
     &       + PAB1*PCD1*RR(M, 1)*DCONJG(C(ND2+LBAS,IB))*C(NA2+IBAS,IB)
C
          ENDDO
        ENDDO
      ENDIF
C
C     9TH CASE (EXCHANGE)
      IF(IFLG(9).EQ.1) THEN
        M = 0
        DO KBAS=1,NBAS(3)
          DO LBAS=1,NBAS(4)
            M = M+1
C
            ETMP4 = ETMP4
     &       +           RR(M, 1)*DCONJG(C(NA1+IBAS,IB))*C(ND1+LBAS,IB)
     &       +           RR(M, 2)*DCONJG(C(NA1+IBAS,IB))*C(ND2+LBAS,IB)
     &       +           RR(M, 9)*DCONJG(C(NA2+IBAS,IB))*C(ND1+LBAS,IB)
     &       +           RR(M,10)*DCONJG(C(NA2+IBAS,IB))*C(ND2+LBAS,IB)
C
            ETMP4 = ETMP4
     &       +           RR(M, 5)*DCONJG(C(NA1+IBAS,IB))*C(ND1+LBAS,IB)
     &       +           RR(M, 6)*DCONJG(C(NA1+IBAS,IB))*C(ND2+LBAS,IB)
     &       +           RR(M,13)*DCONJG(C(NA2+IBAS,IB))*C(ND1+LBAS,IB)
     &       +           RR(M,14)*DCONJG(C(NA2+IBAS,IB))*C(ND2+LBAS,IB)
C
            ETMP4 = ETMP4
     &       +           RR(M, 3)*DCONJG(C(NA1+IBAS,IB))*C(ND1+LBAS,IB)
     &       +           RR(M, 4)*DCONJG(C(NA1+IBAS,IB))*C(ND2+LBAS,IB)
     &       +           RR(M,11)*DCONJG(C(NA2+IBAS,IB))*C(ND1+LBAS,IB)
     &       +           RR(M,12)*DCONJG(C(NA2+IBAS,IB))*C(ND2+LBAS,IB)
C
            ETMP4 = ETMP4
     &       +           RR(M, 7)*DCONJG(C(NA1+IBAS,IB))*C(ND1+LBAS,IB)
     &       +           RR(M, 8)*DCONJG(C(NA1+IBAS,IB))*C(ND2+LBAS,IB)
     &       +           RR(M,15)*DCONJG(C(NA2+IBAS,IB))*C(ND1+LBAS,IB)
     &       +           RR(M,16)*DCONJG(C(NA2+IBAS,IB))*C(ND2+LBAS,IB)
C
          ENDDO
        ENDDO
      ENDIF
C
C     10TH CASE (EXCHANGE)
      IF(IFLG(10).EQ.1) THEN
        M = 0
        DO KBAS=1,NBAS(3)
          DO LBAS=1,NBAS(4)
            M = M+1
C
            ETMP4 = ETMP4
     &       +      PAB1*RR(M,13)*DCONJG(C(NB1+JBAS,IB))*C(ND1+LBAS,IB)
     &       +      PAB1*RR(M,14)*DCONJG(C(NB1+JBAS,IB))*C(ND2+LBAS,IB)
     &       +      PAB2*RR(M, 9)*DCONJG(C(NB2+JBAS,IB))*C(ND1+LBAS,IB)
     &       +      PAB2*RR(M,10)*DCONJG(C(NB2+JBAS,IB))*C(ND2+LBAS,IB)
C
            ETMP4 = ETMP4
     &       +      PAB2*RR(M, 5)*DCONJG(C(NB1+JBAS,IB))*C(ND1+LBAS,IB)
     &       +      PAB2*RR(M, 6)*DCONJG(C(NB1+JBAS,IB))*C(ND2+LBAS,IB)
     &       +      PAB1*RR(M, 1)*DCONJG(C(NB2+JBAS,IB))*C(ND1+LBAS,IB)
     &       +      PAB1*RR(M, 2)*DCONJG(C(NB2+JBAS,IB))*C(ND2+LBAS,IB)
C
            ETMP4 = ETMP4
     &       +      PAB1*RR(M,15)*DCONJG(C(NB1+JBAS,IB))*C(ND1+LBAS,IB)
     &       +      PAB1*RR(M,16)*DCONJG(C(NB1+JBAS,IB))*C(ND2+LBAS,IB)
     &       +      PAB2*RR(M,11)*DCONJG(C(NB2+JBAS,IB))*C(ND1+LBAS,IB)
     &       +      PAB2*RR(M,12)*DCONJG(C(NB2+JBAS,IB))*C(ND2+LBAS,IB)
C
            ETMP4 = ETMP4
     &       +      PAB2*RR(M, 7)*DCONJG(C(NB1+JBAS,IB))*C(ND1+LBAS,IB)
     &       +      PAB2*RR(M, 8)*DCONJG(C(NB1+JBAS,IB))*C(ND2+LBAS,IB)
     &       +      PAB1*RR(M, 3)*DCONJG(C(NB2+JBAS,IB))*C(ND1+LBAS,IB)
     &       +      PAB1*RR(M, 4)*DCONJG(C(NB2+JBAS,IB))*C(ND2+LBAS,IB)
C
          ENDDO
        ENDDO
      ENDIF
C
C     11TH CASE (EXCHANGE)
      IF(IFLG(11).EQ.1) THEN
        M = 0
        DO KBAS=1,NBAS(3)
          DO LBAS=1,NBAS(4)
            M = M+1
C
            ETMP4 = ETMP4
     &       +      PCD1*RR(M, 4)*DCONJG(C(NA1+IBAS,IB))*C(NC1+KBAS,IB)
     &       +      PCD2*RR(M, 2)*DCONJG(C(NA1+IBAS,IB))*C(NC2+KBAS,IB)
     &       +      PCD1*RR(M,12)*DCONJG(C(NA2+IBAS,IB))*C(NC1+KBAS,IB)
     &       +      PCD2*RR(M,10)*DCONJG(C(NA2+IBAS,IB))*C(NC2+KBAS,IB)
C
            ETMP4 = ETMP4
     &       +      PCD1*RR(M, 8)*DCONJG(C(NA1+IBAS,IB))*C(NC1+KBAS,IB)
     &       +      PCD2*RR(M, 6)*DCONJG(C(NA1+IBAS,IB))*C(NC2+KBAS,IB)
     &       +      PCD1*RR(M,16)*DCONJG(C(NA2+IBAS,IB))*C(NC1+KBAS,IB)
     &       +      PCD2*RR(M,14)*DCONJG(C(NA2+IBAS,IB))*C(NC2+KBAS,IB)
C
            ETMP4 = ETMP4
     &       +      PCD2*RR(M, 3)*DCONJG(C(NA1+IBAS,IB))*C(NC1+KBAS,IB)
     &       +      PCD1*RR(M, 1)*DCONJG(C(NA1+IBAS,IB))*C(NC2+KBAS,IB)
     &       +      PCD2*RR(M,11)*DCONJG(C(NA2+IBAS,IB))*C(NC1+KBAS,IB)
     &       +      PCD1*RR(M, 9)*DCONJG(C(NA2+IBAS,IB))*C(NC2+KBAS,IB)
C
            ETMP4 = ETMP4
     &       +      PCD2*RR(M, 7)*DCONJG(C(NA1+IBAS,IB))*C(NC1+KBAS,IB)
     &       +      PCD1*RR(M, 5)*DCONJG(C(NA1+IBAS,IB))*C(NC2+KBAS,IB)
     &       +      PCD2*RR(M,15)*DCONJG(C(NA2+IBAS,IB))*C(NC1+KBAS,IB)
     &       +      PCD1*RR(M,13)*DCONJG(C(NA2+IBAS,IB))*C(NC2+KBAS,IB)
C
          ENDDO
        ENDDO
      ENDIF
C
C     LOOP OVER OCCUPIED SPINORS IOCCB
      DO 7000 IOCCA=1,NOCC
        IA = IOCCA + NSHIFT

C        EAB1(IOCCA,IOCCB,4) = EAB1(IOCCA,IOCCB,4)
C     &                      + ETMP3*

C     END LOOP OVER OCCUPIED SPINORS IOCCB
7000  CONTINUE
C
C     CONTRACTION OVER IOCCB IS FINISHED -- NOW CONTRACT OVER IOCCA

C     END LOOP OVER OCCUPIED SPINORS IOCCB
6000  CONTINUE
C     SKIPPING POINT FOR INTEGRAL SCREENING
5001  CONTINUE
C     RECORD CPU TIME AT END OF BATCH AND ADD TO TIME COUNTER
      CALL CPU_TIME(TBCH2)
      T2ES(MCNT,ITT) = T2ES(MCNT,ITT) + TBCH2 - TBCH1
C     END LOOP OVER IBAS AND JBAS
5000  CONTINUE
C     SKIPPING POINT FOR MQN SELECTION RULES AND INTEGRAL SYMMETRY
4001  CONTINUE
C     END LOOP OVER |MQN| VALUES A AND B
4000  CONTINUE
C     SKIPPING POINT FOR INCLUSION LEVELS
3001  CONTINUE
C     END LOOP OVER CENTERS AND KQNS C AND D
3000  CONTINUE
C     END LOOP OVER CENTERS AND KQNS A AND B
2000  CONTINUE
C     END LOOP OVER COMPONENT OVERLAPS
1000  CONTINUE
C
C     CALCULATE TWO-BODY MATRIX FOR COULOMB INTERACTION
      CALL COULOMB
      CALL COULOMB1
C
C     LOOP OVER ALL OCCUPIED SPINOR PAIRS
      DO IOCCA=1,NOCC
        DO IOCCB=1,IOCCA
C
          IA = IOCCA + NSHIFT
          IB = IOCCB + NSHIFT
C
C         COULOMB SCF INTERACTION ENERGY
          ETMP3 = DCMPLX(0.0D0,0.0D0)
          ETMP4 = DCMPLX(0.0D0,0.0D0)
          DO J=1,NDIM
            DO I=1,NDIM
              ETMP3 = ETMP3 + DCONJG(C(I,IA))*C(J,IB)*GDIR(I,J)
              ETMP4 = ETMP4 - DCONJG(C(I,IA))*C(J,IB)*GXCH(I,J)
            ENDDO
          ENDDO
C
C         ADD RESULTS TO AN ARRAY FOR USE LATER
          EAB1(IOCCA,IOCCB,4) = DREAL(ETMP3)
          EAB1(IOCCA,IOCCB,5) = DREAL(ETMP4)
          EAB1(IOCCA,IOCCB,6) = DREAL(ETMP3+ETMP4)+EAB1(IOCCA,IOCCB,3)
C
        ENDDO
      ENDDO
C
C     FINISH CONSTRUCTION BY SYMMETRY
      DO IOCCA=1,NOCC
        DO IOCCB=1,IOCCA-1
          DO N=1,6
            EAB1(IOCCB,IOCCA,N) = EAB1(IOCCA,IOCCB,N)
          ENDDO
        ENDDO
      ENDDO
C
C     RECORD TIME AT THE END OF MAIN CALCULATION
      CALL CPU_TIME(TDM2)
C
C     WRITE RESULTS OF EAB ENERGIES TO AN EXTERNAL FILE
      OPEN(UNIT=8,FILE=TRIM(OUTFL)//'_MBPT1.dat',STATUS='UNKNOWN')
      REWIND(UNIT=8)
      DO IOCCA=1,NOCC
        DO IOCCB=1,NOCC
          WRITE(8, *) (EAB1(IOCCA,IOCCB,N),N=1,6)
        ENDDO
      ENDDO
      CLOSE(UNIT=8)
C
C**********************************************************************C
C     PRINT PAIRWISE RESULTS                                           C
C**********************************************************************C
C
C     PRINT ENERGY CONTRIBUTIONS TO EACH ELECTRON PAIR
20    FORMAT(1X,A,11X,A,11X,A,11X,A,11X,A)
21    FORMAT(' (',I2,',',I2,')',3X,F13.7,5X,F11.7,5X,F11.7,4X,F13.7)
      WRITE(6, *) ' '
      WRITE(7, *) ' '
      WRITE(6, *) REPEAT(' ',24),'MP1 pair-wise summary'
      WRITE(7, *) REPEAT(' ',24),'MP1 pair-wise summary'
      WRITE(6, *) REPEAT('-',72)
      WRITE(7, *) REPEAT('-',72)
      WRITE(6,20) '( a, b)','E1(H)','E1(J)','E1(K)','E1(ab)'
      WRITE(7,20) '( a, b)','E1(H)','E1(J)','E1(K)','E1(ab)'
      WRITE(6, *) REPEAT('-',72)
      WRITE(7, *) REPEAT('-',72)
C
      DO IOCCA=1,NOCC
        DO IOCCB=1,IOCCA
C
C         PRINT RESULTS TO TERMINAL
          WRITE(6,21) IOCCA,IOCCB,(EAB1(IOCCA,IOCCB,N),N=3,6)
          WRITE(7,21) IOCCA,IOCCB,(EAB1(IOCCA,IOCCB,N),N=3,6)
C
        ENDDO
      ENDDO
C
C**********************************************************************C
C     PRINT INDEPENDENT SPINOR RESULTS                                 C
C**********************************************************************C
C
C     CALCULATE MP1 SINGLE-PARTICLE ENERGIES AND MOLECULAR TOTALS
      EENC1 = 0.0D0
      EKIN1 = 0.0D0
      EBAR1 = 0.0D0
      EDIR1 = 0.0D0
      EXCH1 = 0.0D0
      DO IOCCA=1,NOCC
        DO N=1,5
          EA1(IOCCA,N) = 0.0D0
          DO IOCCB=1,NOCC
            EA1(IOCCA,N) = EA1(IOCCA,N) + EAB1(IOCCA,IOCCB,N)
          ENDDO
        ENDDO
        EA1(IOCCA,6) = EA1(IOCCA,3) + EA1(IOCCA,4) - EA1(IOCCA,5)
        EENC1 = EENC1 + EA1(IOCCA,1)
        EKIN1 = EKIN1 + EA1(IOCCA,2)
        EBAR1 = EBAR1 + EA1(IOCCA,3)
        EDIR1 = EDIR1 + EA1(IOCCA,4)*0.5D0
        EXCH1 = EXCH1 + EA1(IOCCA,5)*0.5D0
      ENDDO
      ETOT1 = EBAR1 + EDIR1 - EXCH1 + ENUC
C
C     MP1 SINGLE-PARTICLE SUMMARY
30    FORMAT(1X,A,11X,A,11X,A,11X,A,11X,A)
31    FORMAT('  ',I2,'    ',3X,F13.7,5X,F11.7,5X,F11.7,4X,F13.7)

      WRITE(6, *) REPEAT('-',72)
      WRITE(7, *) REPEAT('-',72)
      WRITE(6, *) ' '
      WRITE(7, *) ' '
      WRITE(6, *) REPEAT(' ',21),'MP1 single particle summary'
      WRITE(7, *) REPEAT(' ',21),'MP1 single particle summary'
      WRITE(6, *) REPEAT('-',72)
      WRITE(7, *) REPEAT('-',72)
      WRITE(6,30) '  a    ','E1(H)','E1(J)','E1(K)',' E1(a)'
      WRITE(7,30) '  a    ','E1(H)','E1(J)','E1(K)',' E1(a)'
      WRITE(6, *) REPEAT('-',72)
      WRITE(7, *) REPEAT('-',72)
      DO IOCCA=1,NOCC
        WRITE(6,31) IOCCA,(EA1(IOCCA,N),N=3,6)
        WRITE(7,31) IOCCA,(EA1(IOCCA,N),N=3,6)
      ENDDO
      WRITE(6, *) REPEAT('-',72)
      WRITE(7, *) REPEAT('-',72)
C
C     SUMMARY OF MOLECULAR ENERGY SOURCES
32    FORMAT(1X,A,4X,A,2X,'=',10X,F18.8,' au')
33    FORMAT(1X,A,5X,'=',23X,A)
      WRITE(6, *) ' '
      WRITE(7, *) ' '
      WRITE(6, *) REPEAT(' ',25),'MP1 molecular summary'
      WRITE(7, *) REPEAT(' ',25),'MP1 molecular summary'
      WRITE(6, *) REPEAT('-',72)
      WRITE(7, *) REPEAT('-',72)
      WRITE(6,32) 'Hartree-Fock electron-nucleus','E1(V)',EENC1
      WRITE(7,32) 'Hartree-Fock electron-nucleus','E1(V)',EENC1
      WRITE(6,32) 'Hartree-Fock electron kinetic','E1(T)',EKIN1
      WRITE(7,32) 'Hartree-Fock electron kinetic','E1(T)',EKIN1
      WRITE(6,32) 'Hartree-Fock Coulomb direct  ','E1(J)',EDIR1
      WRITE(7,32) 'Hartree-Fock Coulomb direct  ','E1(J)',EDIR1
      WRITE(6,32) 'Hartree-Fock Coulomb exchange','E1(K)',EXCH1
      WRITE(7,32) 'Hartree-Fock Coulomb exchange','E1(K)',EXCH1
      WRITE(6, *) REPEAT('-',72)
      WRITE(7, *) REPEAT('-',72)
      WRITE(6,32) 'Nuclear repulsion            ','E0(N)',ENUC
      WRITE(7,32) 'Nuclear repulsion            ','E0(N)',ENUC
      WRITE(6,32) 'Hartree-Fock one-electron    ','E1(H)',EBAR1
      WRITE(7,32) 'Hartree-Fock one-electron    ','E1(H)',EBAR1
      WRITE(6,32) 'Hartree-Fock Coulomb total   ','E1(G)',EDIR1-EXCH1
      WRITE(7,32) 'Hartree-Fock Coulomb total   ','E1(G)',EDIR1-EXCH1
      WRITE(6,32) 'Hartree-Fock molecular energy','E1   ',ETOT1
      WRITE(7,32) 'Hartree-Fock molecular energy','E1   ',ETOT1
      WRITE(6, *) REPEAT('-',72)
      WRITE(7, *) REPEAT('-',72)
      WRITE(6,33) 'MP1 time                   ',HMS(TDM2-TDM1)
      WRITE(7,33) 'MP1 time                   ',HMS(TDM2-TDM1)
      WRITE(6, *) REPEAT('-',72)
      WRITE(7, *) REPEAT('-',72)
C
      RETURN
      END

