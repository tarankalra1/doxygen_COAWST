      SUBROUTINE set_diags (ng, tile)
!
!svn $Id: set_diags.F 795 2016-05-11 01:42:43Z arango $
!================================================== Hernan G. Arango ===
!  Copyright (c) 2002-2016 The ROMS/TOMS Group                         !
!    Licensed under a MIT/X style license                              !
!    See License_ROMS.txt                                              !
!=======================================================================
!                                                                      !
!  This subroutine accumulates and computes output time-averaged       !
!  diagnostic fields.  Due to synchronization, the time-averaged       !
!  diagnostic fields are computed in delayed mode. All averages        !
!  are accumulated at the beginning of the next time-step.             !
!                                                                      !
!=======================================================================
!
      USE mod_param
      USE mod_scalars
      USE mod_stepping
!
      implicit none
!
!  Imported variable declarations.
!
      integer, intent(in) :: ng, tile
!
!  Local variable declarations.
!
      integer :: IminS, ImaxS, JminS, JmaxS
      integer :: LBi, UBi, LBj, UBj, LBij, UBij
!
!  Set horizontal starting and ending indices for automatic private
!  storage arrays.
!
      IminS=BOUNDS(ng)%Istr(tile)-3
      ImaxS=BOUNDS(ng)%Iend(tile)+3
      JminS=BOUNDS(ng)%Jstr(tile)-3
      JmaxS=BOUNDS(ng)%Jend(tile)+3
!
!  Determine array lower and upper bounds in the I- and J-directions.
!
      LBi=BOUNDS(ng)%LBi(tile)
      UBi=BOUNDS(ng)%UBi(tile)
      LBj=BOUNDS(ng)%LBj(tile)
      UBj=BOUNDS(ng)%UBj(tile)
!
!  Set array lower and upper bounds for MIN(I,J) directions and
!  MAX(I,J) directions.
!
      LBij=BOUNDS(ng)%LBij
      UBij=BOUNDS(ng)%UBij
!
      CALL wclock_on (ng, iNLM, 5)
      CALL set_diags_tile (ng, tile,                                    &
     &                     LBi, UBi, LBj, UBj,                          &
     &                     IminS, ImaxS, JminS, JmaxS,                  &
     &                     kstp(ng),                                    &
     &                     nrhs(ng))
      CALL wclock_off (ng, iNLM, 5)
      RETURN
      END SUBROUTINE set_diags
!
!***********************************************************************
      SUBROUTINE set_diags_tile (ng, tile,                              &
     &                           LBi, UBi, LBj, UBj,                    &
     &                           IminS, ImaxS, JminS, JmaxS,            &
     &                           kout, nrhs)
!***********************************************************************
!
      USE mod_param
      USE mod_diags
      USE mod_grid
      USE mod_ocean
      USE mod_scalars
!
      USE bc_2d_mod
      USE bc_3d_mod
      USE exchange_2d_mod
      USE mp_exchange_mod, ONLY : mp_exchange2d
      USE mp_exchange_mod, ONLY : mp_exchange3d
      USE mp_exchange_mod, ONLY : mp_exchange4d
!
      implicit none
!
!  Imported variable declarations.
!
      integer, intent(in) :: ng, tile
      integer, intent(in) :: LBi, UBi, LBj, UBj
      integer, intent(in) :: IminS, ImaxS, JminS, JmaxS
      integer, intent(in) :: kout, nrhs
!
!  Local variable declarations.
!
      integer :: i, it, j, k
      integer :: idiag
      real(r8) :: fac
      real(r8) :: rfac(IminS:ImaxS,JminS:JmaxS)
      real(r8) :: ufac(IminS:ImaxS,JminS:JmaxS)
      real(r8) :: vfac(IminS:ImaxS,JminS:JmaxS)
!
!-----------------------------------------------------------------------
!  Set lower and upper tile bounds and staggered variables bounds for
!  this horizontal domain partition.  Notice that if tile=-1, it will
!  set the values for the global grid.
!-----------------------------------------------------------------------
!
      integer :: Istr, IstrB, IstrP, IstrR, IstrT, IstrM, IstrU
      integer :: Iend, IendB, IendP, IendR, IendT
      integer :: Jstr, JstrB, JstrP, JstrR, JstrT, JstrM, JstrV
      integer :: Jend, JendB, JendP, JendR, JendT
      integer :: Istrm3, Istrm2, Istrm1, IstrUm2, IstrUm1
      integer :: Iendp1, Iendp2, Iendp2i, Iendp3
      integer :: Jstrm3, Jstrm2, Jstrm1, JstrVm2, JstrVm1
      integer :: Jendp1, Jendp2, Jendp2i, Jendp3
!
      Istr   =BOUNDS(ng) % Istr   (tile)
      IstrB  =BOUNDS(ng) % IstrB  (tile)
      IstrM  =BOUNDS(ng) % IstrM  (tile)
      IstrP  =BOUNDS(ng) % IstrP  (tile)
      IstrR  =BOUNDS(ng) % IstrR  (tile)
      IstrT  =BOUNDS(ng) % IstrT  (tile)
      IstrU  =BOUNDS(ng) % IstrU  (tile)
      Iend   =BOUNDS(ng) % Iend   (tile)
      IendB  =BOUNDS(ng) % IendB  (tile)
      IendP  =BOUNDS(ng) % IendP  (tile)
      IendR  =BOUNDS(ng) % IendR  (tile)
      IendT  =BOUNDS(ng) % IendT  (tile)
      Jstr   =BOUNDS(ng) % Jstr   (tile)
      JstrB  =BOUNDS(ng) % JstrB  (tile)
      JstrM  =BOUNDS(ng) % JstrM  (tile)
      JstrP  =BOUNDS(ng) % JstrP  (tile)
      JstrR  =BOUNDS(ng) % JstrR  (tile)
      JstrT  =BOUNDS(ng) % JstrT  (tile)
      JstrV  =BOUNDS(ng) % JstrV  (tile)
      Jend   =BOUNDS(ng) % Jend   (tile)
      JendB  =BOUNDS(ng) % JendB  (tile)
      JendP  =BOUNDS(ng) % JendP  (tile)
      JendR  =BOUNDS(ng) % JendR  (tile)
      JendT  =BOUNDS(ng) % JendT  (tile)
!
      Istrm3 =BOUNDS(ng) % Istrm3 (tile)            ! Istr-3
      Istrm2 =BOUNDS(ng) % Istrm2 (tile)            ! Istr-2
      Istrm1 =BOUNDS(ng) % Istrm1 (tile)            ! Istr-1
      IstrUm2=BOUNDS(ng) % IstrUm2(tile)            ! IstrU-2
      IstrUm1=BOUNDS(ng) % IstrUm1(tile)            ! IstrU-1
      Iendp1 =BOUNDS(ng) % Iendp1 (tile)            ! Iend+1
      Iendp2 =BOUNDS(ng) % Iendp2 (tile)            ! Iend+2
      Iendp2i=BOUNDS(ng) % Iendp2i(tile)            ! Iend+2 interior
      Iendp3 =BOUNDS(ng) % Iendp3 (tile)            ! Iend+3
      Jstrm3 =BOUNDS(ng) % Jstrm3 (tile)            ! Jstr-3
      Jstrm2 =BOUNDS(ng) % Jstrm2 (tile)            ! Jstr-2
      Jstrm1 =BOUNDS(ng) % Jstrm1 (tile)            ! Jstr-1
      JstrVm2=BOUNDS(ng) % JstrVm2(tile)            ! JstrV-2
      JstrVm1=BOUNDS(ng) % JstrVm1(tile)            ! JstrV-1
      Jendp1 =BOUNDS(ng) % Jendp1 (tile)            ! Jend+1
      Jendp2 =BOUNDS(ng) % Jendp2 (tile)            ! Jend+2
      Jendp2i=BOUNDS(ng) % Jendp2i(tile)            ! Jend+2 interior
      Jendp3 =BOUNDS(ng) % Jendp3 (tile)            ! Jend+3
!
!-----------------------------------------------------------------------
!  Return if time-averaging window is zero.
!-----------------------------------------------------------------------
!
      IF (nDIA(ng).eq.0) RETURN
!
!-----------------------------------------------------------------------
! Initialize time-averaged diagnostic arrays when appropriate.  Notice
! that fields are initilized twice during re-start.  However, the time-
! averaged fields are computed correctly.
!-----------------------------------------------------------------------
!
      IF (((iic(ng).gt.ntsDIA(ng)).and.                                 &
     &     (MOD(iic(ng)-1,nDIA(ng)).eq.1)).or.                          &
     &    ((iic(ng).ge.ntsDIA(ng)).and.(nDIA(ng).eq.1)).or.             &
     &    ((nrrec(ng).gt.0).and.(iic(ng).eq.ntstart(ng)))) THEN
!
!  If wetting and drying, initialize time dependent counters for wet
!  points. The time averaged field at each point is only accumulated
!  over wet points since its multiplied by the appropriate mask.
!
        DO j=Jstr,JendR
          DO i=Istr,IendR
            GRID(ng)%pmask_dia(i,j)=MAX(0.0_r8,                         &
     &                                  MIN(GRID(ng)%pmask_full(i,j),   &
     &                                      1.0_r8))
          END DO
        END DO
        DO j=JstrR,JendR
          DO i=IstrR,IendR
            GRID(ng)%rmask_dia(i,j)=MAX(0.0_r8,                         &
     &                                  MIN(GRID(ng)%rmask_full(i,j),   &
     &                                      1.0_r8))
          END DO
        END DO
        DO j=JstrR,JendR
          DO i=Istr,IendR
            GRID(ng)%umask_dia(i,j)=MAX(0.0_r8,                         &
     &                                  MIN(GRID(ng)%umask_full(i,j),   &
     &                                      1.0_r8))
          END DO
        END DO
        DO j=Jstr,JendR
          DO i=IstrR,IendR
            GRID(ng)%vmask_dia(i,j)=MAX(0.0_r8,                         &
     &                                  MIN(GRID(ng)%vmask_full(i,j),   &
     &                                      1.0_r8))
          END DO
        END DO
!
!  Initialize.
!
        DO idiag=1,NDM2d
          DO j=JstrR,JendR
            DO i=Istr,IendR
              DIAGS(ng)%DiaU2d(i,j,idiag)=                              &
     &                  GRID(ng)%umask_full(i,j)*                       &
     &                  DIAGS(ng)%DiaU2wrk(i,j,idiag)
            END DO
          END DO
          DO j=Jstr,JendR
            DO i=IstrR,IendR
              DIAGS(ng)%DiaV2d(i,j,idiag)=                              &
     &                  GRID(ng)%vmask_full(i,j)*                       &
     &                  DIAGS(ng)%DiaV2wrk(i,j,idiag)
            END DO
          END DO
        END DO
        DO idiag=1,NDM3d
          DO k=1,N(ng)
            DO j=JstrR,JendR
              DO i=Istr,IendR
                DIAGS(ng)%DiaU3d(i,j,k,idiag)=                          &
     &                    GRID(ng)%umask_full(i,j)*                     &
     &                    DIAGS(ng)%DiaU3wrk(i,j,k,idiag)
              END DO
            END DO
            DO j=Jstr,JendR
              DO i=IstrR,IendR
                DIAGS(ng)%DiaV3d(i,j,k,idiag)=                          &
     &                    GRID(ng)%vmask_full(i,j)*                     &
     &                    DIAGS(ng)%DiaV3wrk(i,j,k,idiag)
              END DO
            END DO
          END DO
        END DO
!
!-----------------------------------------------------------------------
!  Accumulate time-averaged fields.
!-----------------------------------------------------------------------
!
      ELSE IF (iic(ng).gt.ntsDIA(ng)) THEN
!
!  If wetting and drying, accumulate wet points counters.
!  points. The time averaged field at each point is only accumulated
!  over wet points since its multiplied by the appropriate mask.
!
        DO j=Jstr,JendR
          DO i=Istr,IendR
            GRID(ng)%pmask_dia(i,j)=GRID(ng)%pmask_dia(i,j)+            &
     &                              MAX(0.0_r8,                         &
     &                                  MIN(GRID(ng)%pmask_full(i,j),   &
     &                                      1.0_r8))
          END DO
        END DO
        DO j=JstrR,JendR
          DO i=IstrR,IendR
            GRID(ng)%rmask_dia(i,j)=GRID(ng)%rmask_dia(i,j)+            &
     &                              MAX(0.0_r8,                         &
     &                                  MIN(GRID(ng)%rmask_full(i,j),   &
     &                                      1.0_r8))
          END DO
        END DO
        DO j=JstrR,JendR
          DO i=Istr,IendR
            GRID(ng)%umask_dia(i,j)=GRID(ng)%umask_dia(i,j)+            &
     &                              MAX(0.0_r8,                         &
     &                                  MIN(GRID(ng)%umask_full(i,j),   &
     &                                      1.0_r8))
          END DO
        END DO
        DO j=Jstr,JendR
          DO i=IstrR,IendR
            GRID(ng)%vmask_dia(i,j)=GRID(ng)%vmask_dia(i,j)+            &
     &                              MAX(0.0_r8,                         &
     &                                  MIN(GRID(ng)%vmask_full(i,j),   &
     &                                      1.0_r8))
          END DO
        END DO
!
!  Accumulate diagnostic terms.
!
        DO idiag=1,NDM2d
          DO j=JstrR,JendR
            DO i=Istr,IendR
              DIAGS(ng)%DiaU2d(i,j,idiag)=DIAGS(ng)%DiaU2d(i,j,idiag)+  &
     &                                    GRID(ng)%umask_full(i,j)*     &
     &                                    DIAGS(ng)%DiaU2wrk(i,j,idiag)
            END DO
          END DO
          DO j=Jstr,JendR
            DO i=IstrR,IendR
              DIAGS(ng)%DiaV2d(i,j,idiag)=DIAGS(ng)%DiaV2d(i,j,idiag)+  &
     &                                    GRID(ng)%vmask_full(i,j)*     &
     &                                    DIAGS(ng)%DiaV2wrk(i,j,idiag)
            END DO
          END DO
        END DO
        DO idiag=1,NDM3d
          DO k=1,N(ng)
            DO j=JstrR,JendR
              DO i=Istr,IendR
                DIAGS(ng)%DiaU3d(i,j,k,idiag)=                          &
     &                    DIAGS(ng)%DiaU3d(i,j,k,idiag)+                &
     &                    GRID(ng)%umask_full(i,j)*                     &
     &                    DIAGS(ng)%DiaU3wrk(i,j,k,idiag)
              END DO
            END DO
            DO j=Jstr,JendR
              DO i=IstrR,IendR
                DIAGS(ng)%DiaV3d(i,j,k,idiag)=                          &
     &                    DIAGS(ng)%DiaV3d(i,j,k,idiag)+                &
     &                    GRID(ng)%vmask_full(i,j)*                     &
     &                    DIAGS(ng)%DiaV3wrk(i,j,k,idiag)
              END DO
            END DO
          END DO
        END DO
      END IF
!
!-----------------------------------------------------------------------
!  Convert accumulated sums into time-averages, if appropriate
!-----------------------------------------------------------------------
!
      IF (((iic(ng).gt.ntsDIA(ng)).and.                                 &
     &     (MOD(iic(ng)-1,nDIA(ng)).eq.0).and.                          &
     &     ((iic(ng).ne.ntstart(ng)).or.(nrrec(ng).eq.0))).or.          &
     &    ((iic(ng).ge.ntsDIA(ng)).and.(nDIA(ng).eq.1))) THEN
        IF (DOMAIN(ng)%SouthWest_Test(tile)) THEN
          IF (nDIA(ng).eq.1) THEN
            DIAtime(ng)=time(ng)
          ELSE
            DIAtime(ng)=DIAtime(ng)+REAL(nDIA(ng),r8)*dt(ng)
          END IF
        END IF
!
!  Set time-averaged factors for each C-grid variable type. Notice that
!  the I- and J-ranges are all grid types are the same for convinience.
!  In wetting and drying, the sums are devided by the number of times
!  that each qrid point is wet.
!
        DO j=JstrR,JendR
          DO i=IstrR,IendR
            rfac(i,j)=1.0_r8/MAX(1.0_r8, GRID(ng)%rmask_dia(i,j))
            ufac(i,j)=1.0_r8/MAX(1.0_r8, GRID(ng)%umask_dia(i,j))
            vfac(i,j)=1.0_r8/MAX(1.0_r8, GRID(ng)%vmask_dia(i,j))
          END DO
        END DO
!
!  If last time-step of average window, convert time dependent counters
!  for wet points to time-averaged Land/Sea masks (dry=0, wet=1) for
!  the current average window period. Notice that a grid point is wet
!  if the count is greater than zero for the current time average
!  window.
!
        DO j=Jstr,JendR
          DO i=Istr,IendR
            GRID(ng)%pmask_dia(i,j)=MIN(1.0_r8, GRID(ng)%pmask_dia(i,j))
          END DO
        END DO
        DO j=JstrR,JendR
          DO i=IstrR,IendR
            GRID(ng)%rmask_dia(i,j)=MIN(1.0_r8, GRID(ng)%rmask_dia(i,j))
          END DO
        END DO
        DO j=JstrR,JendR
          DO i=Istr,IendR
            GRID(ng)%umask_dia(i,j)=MIN(1.0_r8, GRID(ng)%umask_dia(i,j))
          END DO
        END DO
        DO j=Jstr,JendR
          DO i=IstrR,IendR
            GRID(ng)%vmask_dia(i,j)=MIN(1.0_r8, GRID(ng)%vmask_dia(i,j))
          END DO
        END DO
!
!  Exchange boundary data.
!
        IF (EWperiodic(ng).or.NSperiodic(ng)) THEN
          CALL exchange_p2d_tile (ng, tile,                             &
     &                            LBi, UBi, LBj, UBj,                   &
     &                            GRID(ng)%pmask_dia)
          CALL exchange_r2d_tile (ng, tile,                             &
     &                            LBi, UBi, LBj, UBj,                   &
     &                            GRID(ng)%rmask_dia)
          CALL exchange_u2d_tile (ng, tile,                             &
     &                            LBi, UBi, LBj, UBj,                   &
     &                            GRID(ng)%umask_dia)
          CALL exchange_v2d_tile (ng, tile,                             &
     &                            LBi, UBi, LBj, UBj,                   &
     &                            GRID(ng)%vmask_dia)
        END IF
        CALL mp_exchange2d (ng, tile, iNLM, 4,                          &
     &                      LBi, UBi, LBj, UBj,                         &
     &                      NghostPoints,                               &
     &                      EWperiodic(ng), NSperiodic(ng),             &
     &                      GRID(ng)%pmask_dia,                         &
     &                      GRID(ng)%rmask_dia,                         &
     &                      GRID(ng)%umask_dia,                         &
     &                      GRID(ng)%vmask_dia)
!
!  Convert accumulated sums to time averages.
!
        DO idiag=1,NDM2d
          DO j=JstrR,JendR
            DO i=Istr,IendR
              DIAGS(ng)%DiaU2d(i,j,idiag)=ufac(i,j)*                    &
     &                                    DIAGS(ng)%DiaU2d(i,j,idiag)
            END DO
          END DO
          DO j=Jstr,JendR
            DO i=IstrR,IendR
              DIAGS(ng)%DiaV2d(i,j,idiag)=vfac(i,j)*                    &
     &                                    DIAGS(ng)%DiaV2d(i,j,idiag)
            END DO
          END DO
        END DO
        DO idiag=1,NDM3d
          DO k=1,N(ng)
            DO j=JstrR,JendR
              DO i=Istr,IendR
                DIAGS(ng)%DiaU3d(i,j,k,idiag)=ufac(i,j)*                &
     &                    DIAGS(ng)%DiaU3d(i,j,k,idiag)
              END DO
            END DO
            DO j=Jstr,JendR
              DO i=IstrR,IendR
                DIAGS(ng)%DiaV3d(i,j,k,idiag)=vfac(i,j)*                &
     &                    DIAGS(ng)%DiaV3d(i,j,k,idiag)
              END DO
            END DO
          END DO
        END DO
!
!-----------------------------------------------------------------------
!  Apply periodic or gradient boundary conditions for output purposes.
!-----------------------------------------------------------------------
!
!
!  2D momentum diagnostics.
!
        DO idiag=1,NDM2d
          CALL bc_u2d_tile (ng, tile,                                   &
     &                      LBi, UBi, LBj, UBj,                         &
     &                      DIAGS(ng)%DiaU2d(:,:,idiag))
          CALL bc_v2d_tile (ng, tile,                                   &
     &                      LBi, UBi, LBj, UBj,                         &
     &                      DIAGS(ng)%DiaV2d(:,:,idiag))
        END DO
        CALL mp_exchange3d (ng, tile, iNLM, 2,                          &
     &                      LBi, UBi, LBj, UBj, 1, NDM2d,               &
     &                      NghostPoints,                               &
     &                      EWperiodic(ng), NSperiodic(ng),             &
     &                      DIAGS(ng)%DiaU2d,                           &
     &                      DIAGS(ng)%DiaV2d)
!
!  3D momentum diagnostics.
!
        DO idiag=1,NDM3d
          CALL bc_u3d_tile (ng, tile,                                   &
     &                      LBi, UBi, LBj, UBj, 1, N(ng),               &
     &                      DIAGS(ng)%DiaU3d(:,:,:,idiag))
          CALL bc_v3d_tile (ng, tile,                                   &
     &                      LBi, UBi, LBj, UBj, 1, N(ng),               &
     &                      DIAGS(ng)%DiaV3d(:,:,:,idiag))
        END DO
        CALL mp_exchange4d (ng, tile, iNLM, 2,                          &
     &                      LBi, UBi, LBj, UBj, 1, N(ng), 1, NDM3d,     &
     &                      NghostPoints,                               &
     &                      EWperiodic(ng), NSperiodic(ng),             &
     &                      DIAGS(ng)%DiaU3d,                           &
     &                      DIAGS(ng)%DiaV3d)
      END IF
      RETURN
      END SUBROUTINE set_diags_tile