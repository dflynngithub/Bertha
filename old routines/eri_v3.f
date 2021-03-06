      SUBROUTINE ERI(RR,XYZ,KQN,MQN,EXPT,NBAS,ITQN,IBAS,JBAS)
      IMPLICIT DOUBLE PRECISION (A-H,O-Z)
C**********************************************************************C
C                                                                      C
C                        EEEEEEEE RRRRRRR  IIII                        C
C                        EE       RR    RR  II                         C
C                        EE       RR    RR  II                         C
C                        EEEEEE   RR    RR  II                         C
C                        EE       RRRRRRR   II                         C
C                        EE       RR    RR  II                         C
C                        EEEEEEEE RR    RR IIII                        C
C                                                                      C
C -------------------------------------------------------------------- C
C  ERI GENERATES A BATCH OF MOLECULAR ELECTRON REPULSION INTEGRALS BY  C
C  MEANS OF THE MCMURCHIE-DAVIDSION ALGORITHM (DOUBLE FINITE SUM OVER  C
C  EQ-COEFFICIENTS AND INTEGRALS OVER A PAIR OF HGTFS.)                C 
C -------------------------------------------------------------------- C
C  INPUT:                                                              C
C    XYZ(3,4)    - COORDINATES OF THE NUCLEAR CENTERS IN THIS BLOCK.   C
C    KQN(4)      - KQN RELATIVISTIC LABELS OF THE CENTERS.             C
C    MQN(4)      - |MQN| QUANTUM NUMBERS OF THE CENTERS.               C
C    EXPT(MBS,4) - LIST OF EXPONENTS IN THE BLOCK.                     C
C    NBAS(4)     - NUMBER OF FUNCTIONS ON CENTER J.                    C
C    ITQN(2)     - COMPONENT OVERLAP (T,T') FOR EACH PAIR AB AND CD.   C
C                  ITQN(I) = {LL,LS,SL,SS}.                            C
C    IBAS,JBAS   - COMPONENT LABEL INDEX FOR AB BASIS FUNCTIONS.       C
C    IEAB/CD/RC  - 0 DON'T RECALCULATE E(AB/CD)/RC(AB|CD) ARRAYS       C
C                  1 DO    RECALCULATE E(AB/CD)/RC(AB|CD) ARRAYS       C
C  OUTPUT:                                                             C
C    RR(MB2,16) - ERI'S FOR BLOCK AB, ALL 16 MQN SIGN COMBINATIONS.    C
C**********************************************************************C
      PARAMETER(MBS=26,MB2=MBS*MBS,MCT=6,MKP=9,MFL=7000000,
     &                          ML2=MKP+1,MEQ=(ML2+1)*(ML2+2)*(ML2+3)/6,
     &                          ML4=2*ML2,MRC=(ML4+1)*(ML4+2)*(ML4+3)/6)
C
      CHARACTER*4 HMLTN
C
      COMPLEX*16 CONE
      COMPLEX*16 RR(MB2,16),Q1(MB2),Q2(MB2)
      COMPLEX*16 EAB11(MB2,MEQ),ECD11(MB2,MEQ),GAB11(MB2,MEQ),
     &           EAB21(MB2,MEQ),ECD21(MB2,MEQ),GAB21(MB2,MEQ)
C
      DIMENSION KQN(4),LQN(4),MQN(4),ITQN(2),NBAS(4),XYZ(3,4)
      DIMENSION EXPT(MBS,4),PQ(MB2,3),APH(MB2),PRE(MB2),RC(MB2,MRC)
      DIMENSION IAB11(MEQ),IAB21(MEQ),ICD11(MEQ),ICD21(MEQ),IRC(MRC)
C
      SAVE EAB11,EAB21,ECD11,ECD21
      SAVE IAB11,IAB21,ICD11,ICD21
C
      COMMON/ACSS/INABCD(0:ML4,0:ML4,0:ML4),
     &             IVEC(MRC),JVEC(MRC),KVEC(MRC),LAMVEC(MRC)
      COMMON/E0LL/E0LLFL(MFL,8),IAD0LL(MCT,MCT,MKP,MKP,MKP,MKP)
      COMMON/E0SS/E0SSFL(MFL,8),IAD0SS(MCT,MCT,MKP,MKP,MKP,MKP)
      COMMON/IQTT/IABLL,ICDLL,IABSS,ICDSS,IABLS,ICDLS
      COMMON/MAKE/IEAB,IECD,IERC,IRIJ(MBS,MBS)
      COMMON/PRMS/CV,HMLTN,ITREE,IMOL,INEW,IEQS,IPAR,ICOR,ILEV
      COMMON/RCTT/RCTTFL(20*MFL),IADRTT(MBS,MBS)
      COMMON/TIME/TATM,TSCF,TMPT,TMCF,TDMG,TPRP,TPLT,TTOT,T1EL,T2CL,
     &            T2BR,TELL,TESS,TELS,TRLL,TRSS,TRLS,TRBR,TBEG,TEND,
     &            TSCR
      COMMON/RKILL/TKILLER,TERI,trmake,tclmb,tclmb1
C
      DATA ROOTPI5,SENS/17.4934183276248628D0,1.0D-10/
C
C     IMAGINARY UNIT i
      CONE = DCMPLX(0.0D0,1.0D0)
C
C     ILLEGAL COMPONENT OVERLAP CHECKER
      DO IT=1,2
        IF(ITQN(IT).NE.1.AND.ITQN(IT).NE.4) THEN
          WRITE(6, *) 'In ERI: illegal component overlaps in ITQN.'
          WRITE(7, *) 'In ERI: illegal component overlaps in ITQN.'
          STOP
        ENDIF
      ENDDO
C
C     EVALUATE LQNS FOR BASIS FUNCTIONS A, B, C, D
      DO N=1,4
        IF(KQN(N).LT.0) THEN
          LQN(N) =-KQN(N)-1
        ELSE
          LQN(N) = KQN(N)
        ENDIF
      ENDDO
C
C     NUMBER OF BASIS FUNCTION OVERLAPS
      MAXAB = NBAS(1)*NBAS(2)
      MAXCD = NBAS(3)*NBAS(4)
C
C     PHASE FACTOR FOR AB AND CD PAIR OVERLAPS
      IPHSAB = 1
      IPHSCD =-1
C
C     VRS MAXIMUM LAMBDA LEVEL FOR EQ(AB)-COEFFICIENTS
      IF(ITQN(1).EQ.1) THEN
        LAMAB = LQN(1)+LQN(2)
      ELSEIF(ITQN(1).EQ.4) THEN
        LAMAB = LQN(1)+LQN(2)+2
      ENDIF
C
C     VRS MAXIMUM LAMBDA LEVEL FOR EQ(CD)-COEFFICIENTS
      IF(ITQN(2).EQ.1) THEN
        LAMCD = LQN(3)+LQN(4)
      ELSEIF(ITQN(2).EQ.4) THEN
        LAMCD = LQN(3)+LQN(4)+2
      ENDIF
C
C     VRS TOTAL LENGTH OF EQ-COEFFICIENT LISTS
      NTUVAB = (LAMAB+1)*(LAMAB+2)*(LAMAB+3)/6
      NTUVCD = (LAMCD+1)*(LAMCD+2)*(LAMCD+3)/6
C
C     VRS MAXIMUM LAMBDA AND LIST LENGTH FOR CONTRACTED R-INTEGRAL BATCH
      LAMABCD  = LAMAB+LAMCD
      NTUVABCD = (LAMABCD+1)*(LAMABCD+2)*(LAMABCD+3)/6
C
C     LIST ADDRESS FOR (AB|  ) AND GAUSSIAN EXPONENT FOR AB OVERLAP
      IJ  = (IBAS-1)*NBAS(2) + JBAS
      EIJ = EXPT(IBAS,1) + EXPT(JBAS,2)
C
C**********************************************************************C
C     GENERATE NEW BATCH OF E(AB|  ) COEFFICIENTS IF PROMPTED          C
C**********************************************************************C
C
      IF(IEAB.EQ.0) GOTO 100
C
C     START TIME
      CALL CPU_TIME(TDM1)
C
C     READ FROM LOCAL EQ-COEFFICIENT FILE
      IF(IEQS.EQ.1) THEN
        IF(ITQN(1).EQ.1) THEN
          DO ITUV=1,NTUVAB
            IAD = IABLL + (ITUV-1)*MAXAB
            DO M=1,MAXAB
              EAB11(M,ITUV) = DCMPLX(E0LLFL(IAD+M,1),E0LLFL(IAD+M,2))
              EAB21(M,ITUV) = DCMPLX(E0LLFL(IAD+M,3),E0LLFL(IAD+M,4))
            ENDDO       
          ENDDO       
        ELSEIF(ITQN(1).EQ.4) THEN
          DO ITUV=1,NTUVAB
            IAD = IABSS + (ITUV-1)*MAXAB
            DO M=1,MAXAB
              EAB11(M,ITUV) = DCMPLX(E0SSFL(IAD+M,1),E0SSFL(IAD+M,2))
              EAB21(M,ITUV) = DCMPLX(E0SSFL(IAD+M,3),E0SSFL(IAD+M,4))
            ENDDO
          ENDDO
        ENDIF
      ENDIF
C
C     CALCULATE FROM SCRATCH
      IF(IEQS.EQ.0) THEN
        IF(ITQN(1).EQ.1) THEN
          CALL EMAKELL(EAB11,EAB21,EXPT,XYZ,KQN,MQN,NBAS,IPHSAB,1,2,0)         
        ELSEIF(ITQN(1).EQ.4) THEN
          CALL EMAKESS(EAB11,EAB21,EXPT,XYZ,KQN,MQN,NBAS,IPHSAB,1,2,0)         
        ENDIF
      ENDIF
C
C     RECORD THE TIME TAKEN TO GENERATE/READ THE E(AB|  ) COEFFICIENTS
      CALL CPU_TIME(TDM2)
      IF(ITQN(1).EQ.1) THEN
        TELL = TELL + TDM2 - TDM1       
      ELSEIF(ITQN(1).EQ.4) THEN
        TESS = TESS + TDM2 - TDM1
      ENDIF
C
C     SCREENING: TEST E(AB| -) COLUMNS OF CARTESIAN INDEX (T ,U ,V )
      DO IAB=1,NTUVAB
C
C       E(AB|--) COEFFICIENTS
        SUM = 0.0D0
        DO M=1,MAXAB
          SUM = SUM + ABS(EAB11(M,IAB))
          IF(SUM.GT.SENS) THEN
            IAB11(IAB) = 1
            GOTO 101
          ENDIF
        ENDDO
        IAB11(IAB) = 0
101     CONTINUE
C
C       E(AB|+-) COEFFICIENTS
        SUM = 0.0D0
        DO M=1,MAXAB
          SUM = SUM + ABS(EAB21(M,IAB))
          IF(SUM.GT.SENS) THEN
            IAB21(IAB) = 1
            GOTO 102
          ENDIF
        ENDDO
        IAB21(IAB) = 0
102     CONTINUE
C        
      ENDDO
C
C     DO NOT CALCULATE AGAIN UNTIL PROMPTED EXTERNALLY
      IEAB = 0
C
100   CONTINUE
C
C**********************************************************************C
C     GENERATE NEW BATCH OF E(CD| -) COEFFICIENTS IF PROMPTED          C
C**********************************************************************C
C
      IF(IECD.EQ.0) GOTO 200
C
C     START TIME
      CALL CPU_TIME(TDM1)
C
C     READ FROM LOCAL EQ-COEFFICIENT FILE
      IF(IEQS.EQ.1) THEN
        IF(ITQN(2).EQ.1) THEN
          DO ITUV=1,NTUVCD
            IAD = ICDLL + (ITUV-1)*MAXCD
            DO M=1,MAXCD
              ECD11(M,ITUV) = DCMPLX(E0LLFL(IAD+M,5),E0LLFL(IAD+M,6))
              ECD21(M,ITUV) = DCMPLX(E0LLFL(IAD+M,7),E0LLFL(IAD+M,8))
            ENDDO       
          ENDDO       
        ELSEIF(ITQN(2).EQ.4) THEN
          DO ITUV=1,NTUVCD
            IAD = ICDSS + (ITUV-1)*MAXCD
            DO M=1,MAXCD
              ECD11(M,ITUV) = DCMPLX(E0SSFL(IAD+M,5),E0SSFL(IAD+M,6))
              ECD21(M,ITUV) = DCMPLX(E0SSFL(IAD+M,7),E0SSFL(IAD+M,8))
            ENDDO
          ENDDO
        ENDIF
      ENDIF
C
C     CALCULATE FROM SCRATCH
      IF(IEQS.EQ.0) THEN
        IF(ITQN(2).EQ.1) THEN
          CALL EMAKELL(ECD11,ECD21,EXPT,XYZ,KQN,MQN,NBAS,IPHSCD,3,4,0)
        ELSEIF(ITQN(2).EQ.4) THEN
          CALL EMAKESS(ECD11,ECD21,EXPT,XYZ,KQN,MQN,NBAS,IPHSCD,3,4,0)
        ENDIF
      ENDIF
C
C     RECORD THE TIME TAKEN TO GENERATE/READ THE E(CD|  ) COEFFICIENTS
      CALL CPU_TIME(TDM2)
      IF(ITQN(2).EQ.1) THEN
        TELL = TELL + TDM2 - TDM1       
      ELSEIF(ITQN(2).EQ.4) THEN
        TESS = TESS + TDM2 - TDM1
      ENDIF
C
C     SCREENING: TEST E(CD| -) COLUMNS OF CARTESIAN INDEX (T',U',V')
      DO ICD=1,NTUVCD
C
C       E(CD|--) COEFFICIENTS
        SUM = 0.0D0
        DO M=1,MAXCD
          SUM = SUM + ABS(ECD11(M,ICD))
          IF(SUM.GT.SENS) THEN
            ICD11(ICD) = 1
            GOTO 201
          ENDIF
        ENDDO
        ICD11(ICD) = 0
201     CONTINUE
C
C       E(CD|+-) COEFFICIENTS
        SUM = 0.0D0
        DO M=1,MAXCD
          SUM = SUM + ABS(ECD21(M,ICD))
          IF(SUM.GT.SENS) THEN
            ICD21(ICD) = 1
            GOTO 202
          ENDIF
        ENDDO
        ICD21(ICD) = 0
202     CONTINUE
C
      ENDDO
C
C     DO NOT CALCULATE AGAIN UNTIL PROMPTED EXTERNALLY
      IECD = 0
C
200   CONTINUE
C
C**********************************************************************C
C     GENERATE NEW BATCH OF RC(AB|CD) FROM SCRATCH OR READ-IN          C
C**********************************************************************C
C
C     START TIME
      CALL CPU_TIME (TDM1)
C
C     READ FROM LOCAL RC(AB|CD) FILE
      IF(IRIJ(IBAS,JBAS).EQ.0) THEN
C
C       STARTING ADDRESS FOR THIS IBAS,JBAS CHOICE
        IAD = IADRTT(IBAS,JBAS)
C
C       READ RC(AB|CD) INTEGRALS FROM THIS STARTING POINT
        M = 0
        DO KBAS=1,NBAS(3)
          DO LBAS=1,NBAS(4)
            M = M+1
            DO IABCD=1,NTUVABCD
              IAD = IAD+1
              RC(M,IABCD) = RCTTFL(IAD)
            ENDDO
          ENDDO
        ENDDO
      ENDIF
C
C     CALCULATE FROM SCRATCH
      IF(IRIJ(IBAS,JBAS).EQ.1) THEN
C
C       GAUSSIAN OVERLAP CENTER
        PX  = (XYZ(1,1)*EXPT(IBAS,1) + XYZ(1,2)*EXPT(JBAS,2))/EIJ
        PY  = (XYZ(2,1)*EXPT(IBAS,1) + XYZ(2,2)*EXPT(JBAS,2))/EIJ
        PZ  = (XYZ(3,1)*EXPT(IBAS,1) + XYZ(3,2)*EXPT(JBAS,2))/EIJ
C
C       AUXILLIARY DATA FOR RMAKE ROUTINE
        M = 0
        DO KBAS=1,NBAS(3)
          DO LBAS=1,NBAS(4)
            M = M+1         
            EKL = EXPT(KBAS,3) + EXPT(LBAS,4)
            QX  = (XYZ(1,3)*EXPT(KBAS,3) + XYZ(1,4)*EXPT(LBAS,4))/EKL
            QY  = (XYZ(2,3)*EXPT(KBAS,3) + XYZ(2,4)*EXPT(LBAS,4))/EKL
            QZ  = (XYZ(3,3)*EXPT(KBAS,3) + XYZ(3,4)*EXPT(LBAS,4))/EKL
            APH(M)  = EIJ*EKL/(EIJ+EKL)
            PQ(M,1) = QX-PX
            PQ(M,2) = QY-PY
            PQ(M,3) = QZ-PZ
          ENDDO
        ENDDO
C
C       GENERATE R-INTEGRALS
        call cpu_time(trmake1)
        CALL RMAKE(RC,PQ,APH,MAXCD,LAMABCD)
        call cpu_time(trmake2)
        trmake = trmake + trmake2 - trmake1
C
C       SAVE THIS SET TO APPROPRIATE CLASS ADDRESS
        IF(IERC.EQ.1) THEN
C
C         TEST WHETHER FINAL ADDRESS IS STILL INSIDE ARRAY BOUNDS
          ILIM = IJ*NBAS(3)*NBAS(4)*NTUVABCD
C
          IF(ILIM.GT.20*MFL) THEN
C           OUT OF BOUNDS: PRINT WARNING BUT KEEP GOING
            WRITE(6, *) 'In ERI: RCTT words exceed allocated limit.'
            WRITE(7, *) 'In ERI: RCTT words exceed allocated limit.'
            GOTO 300
          ELSE
C           DO NOT CALCULATE AGAIN UNTIL PROMPTED EXTERNALLY
            IRIJ(IBAS,JBAS) = 0
          ENDIF
C
C         CALCULATE STARTING ADDRESS TO USE
          IADRTT(IBAS,JBAS) = (IJ-1)*NBAS(3)*NBAS(4)*NTUVABCD
C
C         INCLUDE THIS BATCH OF INTEGRALS IN A BIG CLASS LIST
          M = 0
          DO KBAS=1,NBAS(3)
            DO LBAS=1,NBAS(4)
              M = M+1
              DO IABCD=1,NTUVABCD
                IAD = IADRTT(IBAS,JBAS) + (M-1)*NTUVABCD + IABCD
                RCTTFL(IAD) = RC(M,IABCD)
              ENDDO
            ENDDO
          ENDDO
C
        ENDIF
      ENDIF
300   CONTINUE
C
C     NORMALISATION FACTORS FOR THIS BATCH
      M = 0
      DO KBAS=1,NBAS(3)
        DO LBAS=1,NBAS(4)
          M = M+1
          EKL = EXPT(KBAS,3) + EXPT(LBAS,4)
          EMX    = DSQRT(EIJ+EKL)*EIJ*EKL
          PRE(M) = 2.0D0*ROOTPI5/EMX
        ENDDO
      ENDDO
C
C     RECORD THE TIME TAKEN TO GENERATE THE RC(AB|CD) BATCH
      CALL CPU_TIME(TDM2)
      IF(ITQN(1).EQ.1.AND.ITQN(2).EQ.1) THEN
        TRLL = TRLL + TDM2 - TDM1
      ELSEIF(ITQN(1).EQ.4.AND.ITQN(2).EQ.4) THEN
        TRSS = TRSS + TDM2 - TDM1
      ELSE
        TRLS = TRLS + TDM2 - TDM1
      ENDIF
C
C     SCREENING: TEST RC(AB|CD) COLUMNS WITH INDEX (T+T',U+U',V+V')
      DO IABCD=1,NTUVABCD
C
C       SUM OF RC(AB|CD) MAGNITUDES
        SUM = 0.0D0
        DO M=1,MAXCD
          SUM = SUM + DABS(RC(M,IABCD))
          IF(SUM.GT.SENS) THEN
            IRC(IABCD) = 1
            GOTO 301
          ENDIF
        ENDDO
        IRC(IABCD) = 0
301     CONTINUE
C
      ENDDO
C
C**********************************************************************C
C     PERFORM FIRST CONTRACTION: G(AB| -) = E(CD| -)*RC(AB|CD).        C
C     THIS YIELDS ALL MQN SIGN POSSIBILITIES FOR C AND D.              C
C**********************************************************************C
C
      CALL CPU_TIME(TTT)
C     LOOP OVER ALL ADDRESSES FOR E(AB| -) FINITE EXPANSION
      DO IAB=1,NTUVAB
C
C       RESET CONTRACTION STORAGE ARRAYS G(AB| -)
        DO M=1,MAXCD
          GAB11(M,IAB) = DCMPLX(0.0D0,0.0D0)
          GAB21(M,IAB) = DCMPLX(0.0D0,0.0D0)
        ENDDO
C
C       SKIP ENTIRE PROCESS IF E(AB| -) PASSES SCREENING CONDITION
        IF(IAB11(IAB)+IAB21(IAB).EQ.0) GOTO 799
C
C       LOOP OVER ALL FINITE EXPANSION ADDRESSES FOR E(CD| -)
        DO ICD=1,NTUVCD
C
C         CALCULATE RC ADDRESS FOR THIS PARTICULAR AB/CD OVERLAP
          IRABCD = INABCD(IVEC(IAB)+IVEC(ICD),JVEC(IAB)+JVEC(ICD),
     &                                             KVEC(IAB)+KVEC(ICD))
C
C         SKIP THIS STEP IF THE RC(AB|CD) PASSES SCREENING CONDITION
          IF(IRC(IRABCD).EQ.0) GOTO 798
C
C         CONTRIBUTIONS TO G(AB|--) FROM EACH E(CD|--) ADDRESS
          IF(ICD11(ICD).EQ.1) THEN
            DO M=1,MAXCD
              GAB11(M,IAB) = GAB11(M,IAB) + ECD11(M,ICD)*RC(M,IRABCD)
            ENDDO
          ENDIF
C
C         CONTRIBUTIONS TO G(AB|+-) FROM EACH E(CD|+-) ADDRESS
          IF(ICD21(ICD).EQ.1) THEN
            DO M=1,MAXCD
              GAB21(M,IAB) = GAB21(M,IAB) + ECD21(M,ICD)*RC(M,IRABCD)
            ENDDO
          ENDIF
C
C         SKIP POINT FOR RC(AB|CD) SCREENING
798       CONTINUE
C
C       END LOOP OVER E(CD|  ) FINITE EXPANSION ADDRESSES
        ENDDO
C
C       SKIP POINT FOR E(AB|  ) SCREENING
799     CONTINUE
C
C     END LOOP OVER E(AB|  ) FINITE EXPANSION ADDRESSES
      ENDDO
      CALL CPU_TIME(SSS)
      TKILLER = TKILLER + SSS - TTT
C
C**********************************************************************C
C     PERFORM SECOND CONTRACTION: ( -| -) = E(AB| -)*G(AB| -).         C
C     THIS YIELDS A FULL BATCH OF TWO-ELECTRON INTEGRALS (16 PERM'NS). C
C**********************************************************************C
C
C     CALCULATE PHASES FOR BASIS FUNCTION OVERLAP COMBINATIONS
      PAB = ISIGN(1,KQN(1)*KQN(2))*(-1)**((MQN(1)-MQN(2))/2)
      PCD = ISIGN(1,KQN(3)*KQN(4))*(-1)**((MQN(3)-MQN(4))/2)
C
      PABCD = PAB*PCD
C
C >>> 1ST SET: ( 1) = (--|--)   ( 4) = (--|++)
C              (16) = (++|++)   (13) = (++|--)
C
C     RESET CONTRACTION STORAGE LISTS
      DO M=1,MAXCD
        Q1(M) = DCMPLX(0.0D0,0.0D0)
        Q2(M) = DCMPLX(0.0D0,0.0D0)
      ENDDO
C
C     RAW CONTRACTION (--|--) = E(AB|--)*(Re{G(AB|--)} + i*Im{G(AB|--)})
      DO IAB=1,NTUVAB
        IF(IAB11(IAB).EQ.1) THEN
          DO M=1,MAXCD
            Q1(M) = Q1(M) +      EAB11(IJ,IAB)*DREAL(GAB11(M,IAB))
            Q2(M) = Q2(M) + CONE*EAB11(IJ,IAB)*DIMAG(GAB11(M,IAB))
          ENDDO
        ENDIF
      ENDDO
C
C     APPLY PHASE RELATIONS AND NORMALISATION FACTORS TO RAW CONTRACTION
      DO M=1,MAXCD
        RR(M, 1) =     (Q1(M)+Q2(M))*PRE(M)
        RR(M, 4) = PCD*(Q1(M)-Q2(M))*PRE(M)
        RR(M,16) = PABCD*DCONJG(RR(M, 1))
        RR(M,13) = PABCD*DCONJG(RR(M, 4))
      ENDDO
C
C >>> 2ND SET: ( 3) = (--|+-)   ( 2) = (--|-+) 
C              (14) = (++|-+)   (15) = (++|+-)
C
C     RESET CONTRACTION STORAGE LISTS
      DO M=1,MAXCD
        Q1(M) = DCMPLX(0.0D0,0.0D0)
        Q2(M) = DCMPLX(0.0D0,0.0D0)
      ENDDO
C
C     RAW CONTRACTION (--|+-) = E(AB|--)*(Re{G(AB|+-)} + i*Im{G(AB|+-)})
      DO IAB=1,NTUVAB
        IF(IAB11(IAB).EQ.1) THEN
          DO M=1,MAXCD
            Q1(M) = Q1(M) +      EAB11(IJ,IAB)*DREAL(GAB21(M,IAB))
            Q2(M) = Q2(M) + CONE*EAB11(IJ,IAB)*DIMAG(GAB21(M,IAB))
          ENDDO
        ENDIF
      ENDDO
C
C     APPLY PHASE RELATIONS AND NORMALISATION FACTORS TO RAW CONTRACTION
      DO M=1,MAXCD
        RR(M, 3) =     (Q1(M)+Q2(M))*PRE(M)
        RR(M, 2) =-PCD*(Q1(M)-Q2(M))*PRE(M)
        RR(M,14) =-PABCD*DCONJG(RR(M, 3))
        RR(M,15) =-PABCD*DCONJG(RR(M, 2))
      ENDDO
C
C >>> 3RD SET: ( 9) = (+-|--)   (12) = (+-|++)
C              ( 8) = (-+|++)   ( 5) = (-+|--)
C
C     RESET CONTRACTION STORAGE LISTS
      DO M=1,MAXCD
        Q1(M) = DCMPLX(0.0D0,0.0D0)
        Q2(M) = DCMPLX(0.0D0,0.0D0)
      ENDDO
C
C     RAW CONTRACTION (+-|--) = E(AB|+-)*(Re{G(AB|--)} + i*Im{G(AB|--)})
      DO IAB=1,NTUVAB
       IF(IAB21(IAB).EQ.1) THEN
          DO M=1,MAXCD
            Q1(M) = Q1(M) +      EAB21(IJ,IAB)*DREAL(GAB11(M,IAB))
            Q2(M) = Q2(M) + CONE*EAB21(IJ,IAB)*DIMAG(GAB11(M,IAB))
          ENDDO
       ENDIF
      ENDDO
C
C     APPLY PHASE RELATIONS AND NORMALISATION FACTORS TO RAW CONTRACTION
      DO M=1,MAXCD
        RR(M, 9) =     (Q1(M)+Q2(M))*PRE(M)
        RR(M,12) = PCD*(Q1(M)-Q2(M))*PRE(M)
        RR(M, 8) =-PABCD*DCONJG(RR(M, 9))
        RR(M, 5) =-PABCD*DCONJG(RR(M,12))
      ENDDO
C
C >>> 4TH SET: (11) = (+-|+-)   (10) = (+-|-+)
C              ( 6) = (-+|-+)   ( 7) = (-+|+-)
C
C     RESET CONTRACTION STORAGE LISTS
      DO M=1,MAXCD
        Q1(M) = DCMPLX(0.0D0,0.0D0)
        Q2(M) = DCMPLX(0.0D0,0.0D0)
      ENDDO
C
C     RAW CONTRACTION (+-|+-) = E(AB|+-)*(Re{G(AB|+-)} + i*Im{G(AB|+-)})
      DO IAB=1,NTUVAB
        IF(IAB21(IAB).EQ.1) THEN
          DO M=1,MAXCD
            Q1(M) = Q1(M) +      EAB21(IJ,IAB)*DREAL(GAB21(M,IAB))
            Q2(M) = Q2(M) + CONE*EAB21(IJ,IAB)*DIMAG(GAB21(M,IAB))
          ENDDO
        ENDIF
      ENDDO
C
C     APPLY PHASE RELATIONS AND NORMALISATION FACTORS TO RAW CONTRACTION
      DO M=1,MAXCD
        RR(M,11) =     (Q1(M)+Q2(M))*PRE(M)
        RR(M,10) =-PCD*(Q1(M)-Q2(M))*PRE(M)
        RR(M, 6) = PABCD*DCONJG(RR(M,11))
        RR(M, 7) = PABCD*DCONJG(RR(M,10))
      ENDDO
C
      RETURN
      END
