!----------------------------------------------------------*- Fortran -*-----
!
!                              S E R I A L B O X
!
! This file is distributed under terms of BSD license. 
! See LICENSE.txt for more information.
!
!------------------------------------------------------------------------------

MODULE m_ser
    use mpas_kind_types
    use mpas_log, only : mpas_log_write
    use mpas_derived_types, only : MPAS_LOG_WARN, MPAS_LOG_CRIT

    IMPLICIT NONE

    PUBLIC :: serialize, deserialize, ser_array, ser_init

    INTERFACE ser_array
    MODULE PROCEDURE ser_array_2d
    MODULE PROCEDURE ser_array_3d
    END INTERFACE ser_array
  
    CONTAINS

    

  
    SUBROUTINE serialize(a)
      IMPLICIT NONE
      REAL(KIND=8), DIMENSION(:,:,:) :: a
  
      !$ser init directory='.' prefix='SerialboxTest'
      !$ser savepoint sp1
      !$ser mode write
      !$ser data ser_a=a
  
    END SUBROUTINE serialize
  
    SUBROUTINE deserialize(a)
      IMPLICIT NONE
      REAL(KIND=8), DIMENSION(:,:,:) :: a
  
      !$ser init directory='.' prefix='SerialboxTest-output' prefix_ref='SerialboxTest'
      !$ser savepoint sp1
      !$ser mode read
      !$ser data ser_a=a
      !$ser mode write
      !$ser data ser_a=a
  
    END SUBROUTINE deserialize
  
    SUBROUTINE deserialize_with_perturb(a)
      IMPLICIT NONE
      REAL(KIND=8), DIMENSION(:,:,:) :: a
      REAL(KIND=8) :: rprecision
      rprecision = 10.0**(-PRECISION(1.0))
  
      !$ser init directory='.' prefix='SerialboxTest-output' prefix_ref='SerialboxTest' rprecision=rprecision rperturb=1.0e-5_8
      !$ser savepoint sp1
      !$ser mode read-perturb
      !$ser data ser_a=a
  
    END SUBROUTINE deserialize_with_perturb


    SUBROUTINE ser_init(suffix)
      IMPLICIT NONE
      CHARACTER(LEN=*), INTENT(IN) :: suffix
      REAL(KIND=RKIND) :: rprecision
      rprecision = 10.0**(-PRECISION(1.0))
  
  !    ! $ser verbatim    IF (linitialize) THEN
  
  !#if defined( SERIALIZE_CREATE_REFERENCE )
      !$ser init directory='./ser_data' &
      !$ser&     prefix='reference_'//TRIM(suffix) &
      !$ser&     mpi_rank=0
  ! #else
  !     !$ser init directory='./ser_data' &
  !     !$ser&     prefix='current_'//TRIM(suffix) &
  !     !$ser&     prefix_ref='reference_'//TRIM(suffix) &
  !     !$ser&     mpi_rank=0
  ! #endif
  
  !    !$ser verbatim     linitialize = .FALSE.
  !    !$ser verbatim     END IF
  
    END SUBROUTINE ser_init
 
  

    SUBROUTINE ser_array_d_3d(name, ptr, mode)
      CHARACTER(len=*), INTENT(IN) :: name
      REAL(RKIND), TARGET, INTENT(INOUT) :: ptr(:,:,:)
      REAL(RKIND), DIMENSION(size(ptr, 1), size(ptr, 2), size(ptr, 3)) :: ptr_copy
      INTEGER, INTENT(IN) :: mode
      INTEGER :: i, j, k
      CHARACTER(len=3) :: c="   "
    
      SELECT CASE (mode)
        CASE(0) ! write
          !$ACC PARALLEL LOOP GANG VECTOR COLLAPSE(3) COPYOUT(ptr_copy) ASYNC(1) PRESENT(ptr)
          DO k = 1, size(ptr, 3)
            DO j = 1, size(ptr, 2)
              DO i = 1, size(ptr, 1)
                ptr_copy(i, j, k) = ptr(i, j, k)
              ENDDO
            ENDDO
          ENDDO
          !$ACC END PARALLEL
          !$ACC WAIT(1)
          CALL fs_write_field(ppser_serializer, ppser_savepoint, TRIM(name//c), ptr_copy(:,:,:))
        CASE(1) ! read
          CALL fs_read_field(ppser_serializer_ref, ppser_savepoint, TRIM(name//c), ptr_copy(:,:,:))
          !$ACC PARALLEL LOOP GANG VECTOR COLLAPSE(3) COPYIN(ptr_copy) ASYNC(1) PRESENT(ptr)
          DO k = 1, size(ptr, 3)
            DO j = 1, size(ptr, 2)
              DO i = 1, size(ptr, 1)
                ptr(i, j, k) = ptr_copy(i, j, k)
              ENDDO
            ENDDO
          ENDDO
          !$ACC END PARALLEL
          !$ACC WAIT(1)
        CASE(2) ! read perturb
          CALL fs_read_field(ppser_serializer_ref, ppser_savepoint, TRIM(name//c), ptr_copy(:,:,:), ppser_zrperturb)
          !$ACC PARALLEL LOOP GANG VECTOR COLLAPSE(3) COPYIN(ptr_copy) ASYNC(1) PRESENT(ptr)
          DO k = 1, size(ptr, 3)
            DO j = 1, size(ptr, 2)
              DO i = 1, size(ptr, 1)
                ptr(i, j, k) = ptr_copy(i, j, k)
              ENDDO
            ENDDO
          ENDDO
          !$ACC END PARALLEL
          !$ACC WAIT(1)
        CASE(3) ! compare
          !CALL compare(TRIM(name//c), ptr(:,:,:), o%lopenacc, o%abs_threshold, o%rel_threshold)
          call mpas_log_write('Error: compare mode not defined.', messageType=MPAS_LOG_CRIT)

        CASE DEFAULT
          call mpas_log_write('Error: ser mode not defined.', messageType=MPAS_LOG_CRIT)
      END SELECT
  
    END SUBROUTINE ser_array_d_3d

    SUBROUTINE ser_array_2d(name, ptr, ser_mode)
    CHARACTER(len=*), INTENT(IN) :: name
    REAL(RKIND), TARGET, INTENT(INOUT) :: ptr(:,:)
    REAL(RKIND), DIMENSION(size(ptr, 1), size(ptr, 2)) :: ptr_copy
    INTEGER, INTENT(IN) :: ser_mode
    INTEGER :: i, j
    CHARACTER(len=3) :: c="   "

    SELECT CASE (ser_mode)
        CASE(0) ! write
            !$ACC PARALLEL LOOP GANG VECTOR COLLAPSE(2) COPYOUT(ptr_copy) ASYNC(1) PRESENT(ptr)
            DO j = 1, size(ptr, 2)
                DO i = 1, size(ptr, 1)
                    ptr_copy(i, j) = ptr(i, j)
                ENDDO
            ENDDO
            !$ACC END PARALLEL
            !$ACC WAIT(1)
            CALL fs_write_field(ppser_serializer, ppser_savepoint, TRIM(name//c), ptr_copy(:,:))
        CASE(1) ! read
            CALL fs_read_field(ppser_serializer_ref, ppser_savepoint, TRIM(name//c), ptr_copy(:,:))
            !$ACC PARALLEL LOOP GANG VECTOR COLLAPSE(2) COPYIN(ptr_copy) ASYNC(1) PRESENT(ptr)
            DO j = 1, size(ptr, 2)
                DO i = 1, size(ptr, 1)
                    ptr(i, j) = ptr_copy(i, j)
                ENDDO
            ENDDO
            !$ACC END PARALLEL
            !$ACC WAIT(1)
        CASE DEFAULT
            call mpas_log_write('Error: ser mode not defined.', messageType=MPAS_LOG_CRIT)
    END SELECT
  
  END SUBROUTINE ser_array_2d

    SUBROUTINE ser_array_3d(name, ptr, ser_mode)
      CHARACTER(len=*), INTENT(IN) :: name
      REAL(RKIND), TARGET, INTENT(INOUT) :: ptr(:,:,:)
      REAL(RKIND), DIMENSION(size(ptr, 1), size(ptr, 2), size(ptr, 3)) :: ptr_copy
      INTEGER, INTENT(IN) :: ser_mode
      INTEGER :: i, j, k
      CHARACTER(len=3) :: c="   "
    
      SELECT CASE (ser_mode)
        CASE(0) ! write
          !$ACC PARALLEL LOOP GANG VECTOR COLLAPSE(3) COPYOUT(ptr_copy) ASYNC(1) PRESENT(ptr)
          DO k = 1, size(ptr, 3)
            DO j = 1, size(ptr, 2)
              DO i = 1, size(ptr, 1)
                ptr_copy(i, j, k) = ptr(i, j, k)
              ENDDO
            ENDDO
          ENDDO
          !$ACC END PARALLEL
          !$ACC WAIT(1)
          CALL fs_write_field(ppser_serializer, ppser_savepoint, TRIM(name//c), ptr_copy(:,:,:))
        CASE(1) ! read
          CALL fs_read_field(ppser_serializer_ref, ppser_savepoint, TRIM(name//c), ptr_copy(:,:,:))
          !$ACC PARALLEL LOOP GANG VECTOR COLLAPSE(3) COPYIN(ptr_copy) ASYNC(1) PRESENT(ptr)
          DO k = 1, size(ptr, 3)
            DO j = 1, size(ptr, 2)
              DO i = 1, size(ptr, 1)
                ptr(i, j, k) = ptr_copy(i, j, k)
              ENDDO
            ENDDO
          ENDDO
          !$ACC END PARALLEL
          !$ACC WAIT(1)
        CASE DEFAULT
          call mpas_log_write('Error: ser mode not defined.', messageType=MPAS_LOG_CRIT)
      END SELECT
  
    END SUBROUTINE ser_array_3d
  

  END MODULE m_ser  