
    !-----------------------------------------------------------------------
    !  routine c_loc_assumed_shape_2_1d_real32
    !
    !> \brief Returns a C_PTR for an array with given dimensions
    !> \details
    !>  The Fortran 2003 standard does not permit the use of C_LOC with
    !>  assumed shape arrays. This routine may be used to obtain a C_PTR for
    !>  an assumed shape array by invoking the routine with the first actual
    !>  argument as the assumed-shape array, and subsequent actual arguments
    !>  as, e.g., SIZE(a,DIM=1).
    !>
    !>  Internally, the first dummy argument of this routine can be declared
    !>  as an explicit shape array, which can then be used as an argument to
    !>  C_LOC.
    !>
    !>  Upon success, a C_PTR for the array argument is returned.
    !>
    !>  Note: The actual array argument must not be a zero-sized array.
    !>        Section 15.1.2.5 of the Fortran 2003 standard specifies that
    !>        the argument to C_LOC '...is not an array of zero size...'.
    !
    !-----------------------------------------------------------------------
    function c_loc_assumed_shape_2_1d_real32(a, d1) result(a_ptr)

        use iso_c_binding, only : c_ptr, c_loc, c_float

        implicit none

        ! Arguments
        integer, intent(in) :: d1
        real(kind=c_float), dimension(d1), target, intent(in) :: a

        ! Return value
        type (c_ptr) :: a_ptr

        a_ptr = c_loc(a)

    end function c_loc_assumed_shape_2_1d_real32


    !-----------------------------------------------------------------------
    !  routine SMIOLf_put_var_serialbox_d1_real32
    !
    !> \brief Writes a 1-d real32 variable to a file.
    !> \details
    !>  Given a SMIOL file that was previously opened with write access and the name
    !>  of a variable previously defined in the file with a call to SMIOLf_define_var,
    !>  this routine will write the contents of buf to the variable according to
    !>  the decomposition described by decomp.
    !>
    !>  If decomp is an associated pointer, the variable is assumed to be decomposed
    !>  across MPI ranks, and all ranks with non-zero-sized partitions of the variable
    !>  must provide a valid buffer. For decomposed variables, all MPI ranks must provide
    !>  an associated decomp pointer, regardless of whether a rank has a non-zero-sized
    !>  partition of the variable.
    !>
    !>  If the variable is not decomposed -- that is, all ranks store identical
    !>  values for the entire variable -- all MPI ranks must provide an unassociated
    !>  pointer for the decomp argument. As currently implemented, this routine will write
    !>  the buffer for MPI rank 0 to the variable; however, this behavior should not
    !>  be relied on.
    !>
    !>  If the variable has been successfully written to the file, SMIOL_SUCCESS will
    !>  be returned. Otherwise, an error code indicating the nature of the failure
    !>  will be returned.
    !
    !-----------------------------------------------------------------------
    function SMIOLf_put_var_serialbox_1d_real32(serializer, savepoint, fieldname, &
                                    smiol_file, smiol_varname, decomp, buf) result(ierr)

        use iso_c_binding, only : c_float, c_char, c_loc, c_ptr, c_null_ptr, c_null_char
        use m_serialize
        implicit none

        ! Arguments
        TYPE(t_serializer), INTENT(IN)          :: serializer
        TYPE(t_savepoint) , INTENT(IN)          :: savepoint
        CHARACTER(LEN=*)  , intent(in)          :: fieldname
        type(SMIOLf_file), target :: smiol_file
        character(len=*), intent(in) :: smiol_varname
        type(SMIOLf_decomp), pointer :: decomp
        real(kind=RKIND), dimension(:), pointer :: buf

        ! Return status code
        integer :: ierr

        ! Local variables
        real(kind=c_float), dimension(:), pointer :: buf_1
        INTEGER(C_INT) :: c_type
        integer :: i
        character(kind=c_char), dimension(:), pointer :: c_varname
        type (c_ptr) :: c_file
        type (c_ptr) :: c_decomp
        type (c_ptr) :: c_buf

        print *,'inside SMIOLf_put_var_serialbox_1d_real32 '

        buf_1 => buf

        !
        ! file is a target, so no need to check that it is associated
        !
        c_file = c_loc(smiol_file)

        !
        ! decomp may be an unassociated pointer if the corresponding field is
        ! not decomposed
        !
        if (associated(decomp)) then
            c_decomp = c_loc(decomp)
        else
            c_decomp = c_null_ptr
        end if

        !
        ! Convert variable name string
        !
        allocate(c_varname(len_trim(smiol_varname) + 1))
        do i=1,len_trim(smiol_varname)
            c_varname(i) = smiol_varname(i:i)
        end do
        c_varname(i) = c_null_char

        !
        ! buf may be an unassociated pointer if the calling task does not read
        ! or write any elements of the field
        !
        if (associated(buf_1)) then

            !
            ! Invoke a Fortran 2003-compliant function to get the c_ptr
            ! of the assumed shape array buf
            !
            c_buf = c_loc_assumed_shape_1d_real32(buf, size(buf,dim=1))
        else
            c_buf = c_null_ptr
        end if

        c_type = 4 ! for float32
       
        ierr = SMIOL_put_var_serialbox(serializer%serializer_ptr, savepoint%savepoint_ptr, &
                                        TRIM(fieldname)//C_NULL_CHAR, c_type, &
                                        c_file, c_varname, c_decomp, c_buf)


        deallocate(c_varname)

    end function SMIOLf_put_var_serialbox_1d_real32




    !-----------------------------------------------------------------------
    !  routine c_loc_assumed_shape_1d_real64
    !
    !> \brief Returns a C_PTR for an array with given dimensions
    !> \details
    !>  The Fortran 2003 standard does not permit the use of C_LOC with
    !>  assumed shape arrays. This routine may be used to obtain a C_PTR for
    !>  an assumed shape array by invoking the routine with the first actual
    !>  argument as the assumed-shape array, and subsequent actual arguments
    !>  as, e.g., SIZE(a,DIM=1).
    !>
    !>  Internally, the first dummy argument of this routine can be declared
    !>  as an explicit shape array, which can then be used as an argument to
    !>  C_LOC.
    !>
    !>  Upon success, a C_PTR for the array argument is returned.
    !>
    !>  Note: The actual array argument must not be a zero-sized array.
    !>        Section 15.1.2.5 of the Fortran 2003 standard specifies that
    !>        the argument to C_LOC '...is not an array of zero size...'.
    !
    !-----------------------------------------------------------------------
    function c_loc_assumed_shape_2_1d_real64(a, d1) result(a_ptr)

        use iso_c_binding, only : c_ptr, c_loc, c_double

        implicit none

        ! Arguments
        integer, intent(in) :: d1
        real(kind=c_double), dimension(d1), target, intent(in) :: a

        ! Return value
        type (c_ptr) :: a_ptr

        a_ptr = c_loc(a)

    end function c_loc_assumed_shape_2_1d_real64


    !-----------------------------------------------------------------------
    !  routine SMIOLf_put_var_serialbox_d1_real64
    !
    !> \brief Writes a 1-d real64 variable to a file.
    !> \details
    !>  Given a SMIOL file that was previously opened with write access and the name
    !>  of a variable previously defined in the file with a call to SMIOLf_define_var,
    !>  this routine will write the contents of buf to the variable according to
    !>  the decomposition described by decomp.
    !>
    !>  If decomp is an associated pointer, the variable is assumed to be decomposed
    !>  across MPI ranks, and all ranks with non-zero-sized partitions of the variable
    !>  must provide a valid buffer. For decomposed variables, all MPI ranks must provide
    !>  an associated decomp pointer, regardless of whether a rank has a non-zero-sized
    !>  partition of the variable.
    !>
    !>  If the variable is not decomposed -- that is, all ranks store identical
    !>  values for the entire variable -- all MPI ranks must provide an unassociated
    !>  pointer for the decomp argument. As currently implemented, this routine will write
    !>  the buffer for MPI rank 0 to the variable; however, this behavior should not
    !>  be relied on.
    !>
    !>  If the variable has been successfully written to the file, SMIOL_SUCCESS will
    !>  be returned. Otherwise, an error code indicating the nature of the failure
    !>  will be returned.
    !
    !-----------------------------------------------------------------------
    function SMIOLf_put_var_serialbox_1d_real64(file, varname, decomp, buf) result(ierr)

        use iso_c_binding, only : c_double, c_char, c_loc, c_ptr, c_null_ptr, c_null_char

        implicit none

        ! Arguments
        type(SMIOLf_file), target :: file
        character(len=*), intent(in) :: varname
        type(SMIOLf_decomp), pointer :: decomp
        real(kind=c_double), dimension(:), pointer :: buf

        ! Return status code
        integer :: ierr

        ! Local variables
        integer :: i
        character(kind=c_char), dimension(:), pointer :: c_varname
        type (c_ptr) :: c_file
        type (c_ptr) :: c_decomp
        type (c_ptr) :: c_buf


        !
        ! file is a target, so no need to check that it is associated
        !
        c_file = c_loc(file)

        !
        ! decomp may be an unassociated pointer if the corresponding field is
        ! not decomposed
        !
        if (associated(decomp)) then
            c_decomp = c_loc(decomp)
        else
            c_decomp = c_null_ptr
        end if

        !
        ! Convert variable name string
        !
        allocate(c_varname(len_trim(varname) + 1))
        do i=1,len_trim(varname)
            c_varname(i) = varname(i:i)
        end do
        c_varname(i) = c_null_char

        !
        ! buf may be an unassociated pointer if the calling task does not read
        ! or write any elements of the field
        !
        if (associated(buf)) then

            !
            ! Invoke a Fortran 2003-compliant function to get the c_ptr
            ! of the assumed shape array buf
            !
            c_buf = c_loc_assumed_shape_1d_real64(buf, size(buf,dim=1))
        else
            c_buf = c_null_ptr
        end if

        ierr = SMIOL_put_var(c_file, c_varname, c_decomp, c_buf)


        deallocate(c_varname)

    end function SMIOLf_put_var_serialbox_1d_real64


   


    !-----------------------------------------------------------------------
    !  routine c_loc_assumed_shape_1d_int32
    !
    !> \brief Returns a C_PTR for an array with given dimensions
    !> \details
    !>  The Fortran 2003 standard does not permit the use of C_LOC with
    !>  assumed shape arrays. This routine may be used to obtain a C_PTR for
    !>  an assumed shape array by invoking the routine with the first actual
    !>  argument as the assumed-shape array, and subsequent actual arguments
    !>  as, e.g., SIZE(a,DIM=1).
    !>
    !>  Internally, the first dummy argument of this routine can be declared
    !>  as an explicit shape array, which can then be used as an argument to
    !>  C_LOC.
    !>
    !>  Upon success, a C_PTR for the array argument is returned.
    !>
    !>  Note: The actual array argument must not be a zero-sized array.
    !>        Section 15.1.2.5 of the Fortran 2003 standard specifies that
    !>        the argument to C_LOC '...is not an array of zero size...'.
    !
    !-----------------------------------------------------------------------
    function c_loc_assumed_shape_2_1d_int32(a, d1) result(a_ptr)

        use iso_c_binding, only : c_ptr, c_loc, c_int

        implicit none

        ! Arguments
        integer, intent(in) :: d1
        integer(kind=c_int), dimension(d1), target, intent(in) :: a

        ! Return value
        type (c_ptr) :: a_ptr

        a_ptr = c_loc(a)

    end function c_loc_assumed_shape_2_1d_int32


    !-----------------------------------------------------------------------
    !  routine SMIOLf_put_var_serialbox_d1_int32
    !
    !> \brief Writes a 1-d int32 variable to a file.
    !> \details
    !>  Given a SMIOL file that was previously opened with write access and the name
    !>  of a variable previously defined in the file with a call to SMIOLf_define_var,
    !>  this routine will write the contents of buf to the variable according to
    !>  the decomposition described by decomp.
    !>
    !>  If decomp is an associated pointer, the variable is assumed to be decomposed
    !>  across MPI ranks, and all ranks with non-zero-sized partitions of the variable
    !>  must provide a valid buffer. For decomposed variables, all MPI ranks must provide
    !>  an associated decomp pointer, regardless of whether a rank has a non-zero-sized
    !>  partition of the variable.
    !>
    !>  If the variable is not decomposed -- that is, all ranks store identical
    !>  values for the entire variable -- all MPI ranks must provide an unassociated
    !>  pointer for the decomp argument. As currently implemented, this routine will write
    !>  the buffer for MPI rank 0 to the variable; however, this behavior should not
    !>  be relied on.
    !>
    !>  If the variable has been successfully written to the file, SMIOL_SUCCESS will
    !>  be returned. Otherwise, an error code indicating the nature of the failure
    !>  will be returned.
    !
    !-----------------------------------------------------------------------
    function SMIOLf_put_var_serialbox_1d_int32(file, varname, decomp, buf) result(ierr)

        use iso_c_binding, only : c_int, c_char, c_loc, c_ptr, c_null_ptr, c_null_char

        implicit none

        ! Arguments
        type(SMIOLf_file), target :: file
        character(len=*), intent(in) :: varname
        type(SMIOLf_decomp), pointer :: decomp
        integer(kind=c_int), dimension(:), pointer :: buf

        ! Return status code
        integer :: ierr

        ! Local variables
        integer :: i
        character(kind=c_char), dimension(:), pointer :: c_varname
        type (c_ptr) :: c_file
        type (c_ptr) :: c_decomp
        type (c_ptr) :: c_buf


        !
        ! file is a target, so no need to check that it is associated
        !
        c_file = c_loc(file)

        !
        ! decomp may be an unassociated pointer if the corresponding field is
        ! not decomposed
        !
        if (associated(decomp)) then
            c_decomp = c_loc(decomp)
        else
            c_decomp = c_null_ptr
        end if

        !
        ! Convert variable name string
        !
        allocate(c_varname(len_trim(varname) + 1))
        do i=1,len_trim(varname)
            c_varname(i) = varname(i:i)
        end do
        c_varname(i) = c_null_char

        !
        ! buf may be an unassociated pointer if the calling task does not read
        ! or write any elements of the field
        !
        if (associated(buf)) then

            !
            ! Invoke a Fortran 2003-compliant function to get the c_ptr
            ! of the assumed shape array buf
            !
            c_buf = c_loc_assumed_shape_2_1d_int32(buf, size(buf,dim=1))
        else
            c_buf = c_null_ptr
        end if

        ierr = SMIOL_put_var(c_file, c_varname, c_decomp, c_buf)


        deallocate(c_varname)

    end function SMIOLf_put_var_serialbox_1d_int32


 

    !-----------------------------------------------------------------------
    !  routine c_loc_assumed_shape_2_2d_real32
    !
    !> \brief Returns a C_PTR for an array with given dimensions
    !> \details
    !>  The Fortran 2003 standard does not permit the use of C_LOC with
    !>  assumed shape arrays. This routine may be used to obtain a C_PTR for
    !>  an assumed shape array by invoking the routine with the first actual
    !>  argument as the assumed-shape array, and subsequent actual arguments
    !>  as, e.g., SIZE(a,DIM=1).
    !>
    !>  Internally, the first dummy argument of this routine can be declared
    !>  as an explicit shape array, which can then be used as an argument to
    !>  C_LOC.
    !>
    !>  Upon success, a C_PTR for the array argument is returned.
    !>
    !>  Note: The actual array argument must not be a zero-sized array.
    !>        Section 15.1.2.5 of the Fortran 2003 standard specifies that
    !>        the argument to C_LOC '...is not an array of zero size...'.
    !
    !-----------------------------------------------------------------------
    function c_loc_assumed_shape_2_2d_real32(a, d1, d2) result(a_ptr)

        use iso_c_binding, only : c_ptr, c_loc, c_float

        implicit none

        ! Arguments
        integer, intent(in) :: d1, d2
        real(kind=c_float), dimension(d1,d2), target, intent(in) :: a

        ! Return value
        type (c_ptr) :: a_ptr

        a_ptr = c_loc(a)

    end function c_loc_assumed_shape_2_2d_real32


    !-----------------------------------------------------------------------
    !  routine SMIOLf_put_var_serialbox_d2_real32
    !
    !> \brief Writes a 2-d real32 variable to a file.
    !> \details
    !>  Given a SMIOL file that was previously opened with write access and the name
    !>  of a variable previously defined in the file with a call to SMIOLf_define_var,
    !>  this routine will write the contents of buf to the variable according to
    !>  the decomposition described by decomp.
    !>
    !>  If decomp is an associated pointer, the variable is assumed to be decomposed
    !>  across MPI ranks, and all ranks with non-zero-sized partitions of the variable
    !>  must provide a valid buffer. For decomposed variables, all MPI ranks must provide
    !>  an associated decomp pointer, regardless of whether a rank has a non-zero-sized
    !>  partition of the variable.
    !>
    !>  If the variable is not decomposed -- that is, all ranks store identical
    !>  values for the entire variable -- all MPI ranks must provide an unassociated
    !>  pointer for the decomp argument. As currently implemented, this routine will write
    !>  the buffer for MPI rank 0 to the variable; however, this behavior should not
    !>  be relied on.
    !>
    !>  If the variable has been successfully written to the file, SMIOL_SUCCESS will
    !>  be returned. Otherwise, an error code indicating the nature of the failure
    !>  will be returned.
    !
    !-----------------------------------------------------------------------
    function SMIOLf_put_var_serialbox_2d_real32(serializer, savepoint, fieldname, &
                                    smiol_file, smiol_varname, decomp, buf) result(ierr)

        use iso_c_binding, only : c_float, c_char, c_loc, c_ptr, c_null_ptr, c_null_char
        use m_serialize

        implicit none

        ! Arguments
        TYPE(t_serializer), INTENT(IN)          :: serializer
        TYPE(t_savepoint) , INTENT(IN)          :: savepoint
        CHARACTER(LEN=*)  , intent(in)          :: fieldname
        type(SMIOLf_file), target :: smiol_file
        character(len=*), intent(in) :: smiol_varname
        type(SMIOLf_decomp), pointer :: decomp
        real (kind=RKIND), dimension(:,:), pointer :: buf
 
        ! Return status code
        integer :: ierr

        ! Local variables        
        real(kind=c_float), dimension(:,:), pointer :: buf_1
        INTEGER(C_INT) :: c_type
        integer :: i
        character(kind=c_char), dimension(:), pointer :: c_varname
        type (c_ptr) :: c_file
        type (c_ptr) :: c_decomp
        type (c_ptr) :: c_buf

    
        print *,'inside SMIOLf_put_var_serialbox_2d_real32 '
      

        buf_1 => buf

        !
        ! file is a target, so no need to check that it is associated
        !
        c_file = c_loc(smiol_file)

        !
        ! decomp may be an unassociated pointer if the corresponding field is
        ! not decomposed
        !
        if (associated(decomp)) then
            c_decomp = c_loc(decomp)
            print *,'c_decomp is not null'
        else
            c_decomp = c_null_ptr
        end if
 
        ! Convert variable name string
        !
        allocate(c_varname(len_trim(smiol_varname) + 1))
        do i=1,len_trim(smiol_varname)
            c_varname(i) = smiol_varname(i:i)
        end do
        c_varname(i) = c_null_char

        !
        ! buf may be an unassociated pointer if the calling task does not read
        ! or write any elements of the field
        !
        if (associated(buf_1)) then

            !
            ! Invoke a Fortran 2003-compliant function to get the c_ptr
            ! of the assumed shape array buf
            !
            c_buf = c_loc_assumed_shape_2_2d_real32(buf_1, size(buf_1,dim=1), size(buf_1,dim=2))
            print *,'c_buf is not null'
        else
            c_buf = c_null_ptr
        end if


! // CASE('bool')
! //     c_type = 1
! //   CASE('int')
! //     c_type = 2
! //   CASE('long')
! //     c_type = 3
! //   CASE('float')
! //     c_type = 4
! //   CASE('double')
! //     c_type = 5
! //   END SELECT

        c_type = 4
       
        ierr = SMIOL_put_var_serialbox(serializer%serializer_ptr, savepoint%savepoint_ptr, &
                                        TRIM(fieldname)//C_NULL_CHAR, c_type, &
                                        c_file, c_varname, c_decomp, c_buf)

        deallocate(c_varname)

        

    end function SMIOLf_put_var_serialbox_2d_real32


  
    !-----------------------------------------------------------------------
    !  routine c_loc_assumed_shape_2_2d_real64
    !
    !> \brief Returns a C_PTR for an array with given dimensions
    !> \details
    !>  The Fortran 2003 standard does not permit the use of C_LOC with
    !>  assumed shape arrays. This routine may be used to obtain a C_PTR for
    !>  an assumed shape array by invoking the routine with the first actual
    !>  argument as the assumed-shape array, and subsequent actual arguments
    !>  as, e.g., SIZE(a,DIM=1).
    !>
    !>  Internally, the first dummy argument of this routine can be declared
    !>  as an explicit shape array, which can then be used as an argument to
    !>  C_LOC.
    !>
    !>  Upon success, a C_PTR for the array argument is returned.
    !>
    !>  Note: The actual array argument must not be a zero-sized array.
    !>        Section 15.1.2.5 of the Fortran 2003 standard specifies that
    !>        the argument to C_LOC '...is not an array of zero size...'.
    !
    !-----------------------------------------------------------------------
    function c_loc_assumed_shape_2_2d_real64(a, d1, d2) result(a_ptr)

        use iso_c_binding, only : c_ptr, c_loc, c_double

        implicit none

        ! Arguments
        integer, intent(in) :: d1, d2
        real(kind=c_double), dimension(d1,d2), target, intent(in) :: a

        ! Return value
        type (c_ptr) :: a_ptr

        a_ptr = c_loc(a)

    end function c_loc_assumed_shape_2_2d_real64


    !-----------------------------------------------------------------------
    !  routine SMIOLf_put_var_serialbox_d2_real64
    !
    !> \brief Writes a 2-d real64 variable to a file.
    !> \details
    !>  Given a SMIOL file that was previously opened with write access and the name
    !>  of a variable previously defined in the file with a call to SMIOLf_define_var,
    !>  this routine will write the contents of buf to the variable according to
    !>  the decomposition described by decomp.
    !>
    !>  If decomp is an associated pointer, the variable is assumed to be decomposed
    !>  across MPI ranks, and all ranks with non-zero-sized partitions of the variable
    !>  must provide a valid buffer. For decomposed variables, all MPI ranks must provide
    !>  an associated decomp pointer, regardless of whether a rank has a non-zero-sized
    !>  partition of the variable.
    !>
    !>  If the variable is not decomposed -- that is, all ranks store identical
    !>  values for the entire variable -- all MPI ranks must provide an unassociated
    !>  pointer for the decomp argument. As currently implemented, this routine will write
    !>  the buffer for MPI rank 0 to the variable; however, this behavior should not
    !>  be relied on.
    !>
    !>  If the variable has been successfully written to the file, SMIOL_SUCCESS will
    !>  be returned. Otherwise, an error code indicating the nature of the failure
    !>  will be returned.
    !
    !-----------------------------------------------------------------------
    function SMIOLf_put_var_serialbox_2d_real64(file, varname, decomp, buf) result(ierr)

        use iso_c_binding, only : c_double, c_char, c_loc, c_ptr, c_null_ptr, c_null_char

        implicit none

        ! Arguments
        type(SMIOLf_file), target :: file
        character(len=*), intent(in) :: varname
        type(SMIOLf_decomp), pointer :: decomp
        real(kind=c_double), dimension(:,:), pointer :: buf

        ! Return status code
        integer :: ierr

        ! Local variables
        integer :: i
        character(kind=c_char), dimension(:), pointer :: c_varname
        type (c_ptr) :: c_file
        type (c_ptr) :: c_decomp
        type (c_ptr) :: c_buf


        !
        ! file is a target, so no need to check that it is associated
        !
        c_file = c_loc(file)

        !
        ! decomp may be an unassociated pointer if the corresponding field is
        ! not decomposed
        !
        if (associated(decomp)) then
            c_decomp = c_loc(decomp)
        else
            c_decomp = c_null_ptr
        end if

        !
        ! Convert variable name string
        !
        allocate(c_varname(len_trim(varname) + 1))
        do i=1,len_trim(varname)
            c_varname(i) = varname(i:i)
        end do
        c_varname(i) = c_null_char

        !
        ! buf may be an unassociated pointer if the calling task does not read
        ! or write any elements of the field
        !
        if (associated(buf)) then

            !
            ! Invoke a Fortran 2003-compliant function to get the c_ptr
            ! of the assumed shape array buf
            !
            c_buf = c_loc_assumed_shape_2_2d_real64(buf, size(buf,dim=1), size(buf,dim=2))
        else
            c_buf = c_null_ptr
        end if

        ierr = SMIOL_put_var(c_file, c_varname, c_decomp, c_buf)


        deallocate(c_varname)

    end function SMIOLf_put_var_serialbox_2d_real64




    !-----------------------------------------------------------------------
    !  routine c_loc_assumed_shape_2_2d_int32
    !
    !> \brief Returns a C_PTR for an array with given dimensions
    !> \details
    !>  The Fortran 2003 standard does not permit the use of C_LOC with
    !>  assumed shape arrays. This routine may be used to obtain a C_PTR for
    !>  an assumed shape array by invoking the routine with the first actual
    !>  argument as the assumed-shape array, and subsequent actual arguments
    !>  as, e.g., SIZE(a,DIM=1).
    !>
    !>  Internally, the first dummy argument of this routine can be declared
    !>  as an explicit shape array, which can then be used as an argument to
    !>  C_LOC.
    !>
    !>  Upon success, a C_PTR for the array argument is returned.
    !>
    !>  Note: The actual array argument must not be a zero-sized array.
    !>        Section 15.1.2.5 of the Fortran 2003 standard specifies that
    !>        the argument to C_LOC '...is not an array of zero size...'.
    !
    !-----------------------------------------------------------------------
    function c_loc_assumed_shape_2_2d_int32(a, d1, d2) result(a_ptr)

        use iso_c_binding, only : c_ptr, c_loc, c_int

        implicit none

        ! Arguments
        integer, intent(in) :: d1, d2
        integer(kind=c_int), dimension(d1,d2), target, intent(in) :: a

        ! Return value
        type (c_ptr) :: a_ptr

        a_ptr = c_loc(a)

    end function c_loc_assumed_shape_2_2d_int32


    !-----------------------------------------------------------------------
    !  routine SMIOLf_put_var_serialbox_d2_int32
    !
    !> \brief Writes a 2-d int32 variable to a file.
    !> \details
    !>  Given a SMIOL file that was previously opened with write access and the name
    !>  of a variable previously defined in the file with a call to SMIOLf_define_var,
    !>  this routine will write the contents of buf to the variable according to
    !>  the decomposition described by decomp.
    !>
    !>  If decomp is an associated pointer, the variable is assumed to be decomposed
    !>  across MPI ranks, and all ranks with non-zero-sized partitions of the variable
    !>  must provide a valid buffer. For decomposed variables, all MPI ranks must provide
    !>  an associated decomp pointer, regardless of whether a rank has a non-zero-sized
    !>  partition of the variable.
    !>
    !>  If the variable is not decomposed -- that is, all ranks store identical
    !>  values for the entire variable -- all MPI ranks must provide an unassociated
    !>  pointer for the decomp argument. As currently implemented, this routine will write
    !>  the buffer for MPI rank 0 to the variable; however, this behavior should not
    !>  be relied on.
    !>
    !>  If the variable has been successfully written to the file, SMIOL_SUCCESS will
    !>  be returned. Otherwise, an error code indicating the nature of the failure
    !>  will be returned.
    !
    !-----------------------------------------------------------------------
    function SMIOLf_put_var_serialbox_2d_int32(file, varname, decomp, buf) result(ierr)

        use iso_c_binding, only : c_int, c_char, c_loc, c_ptr, c_null_ptr, c_null_char

        implicit none

        ! Arguments
        type(SMIOLf_file), target :: file
        character(len=*), intent(in) :: varname
        type(SMIOLf_decomp), pointer :: decomp
        integer(kind=c_int), dimension(:,:), pointer :: buf

        ! Return status code
        integer :: ierr

        ! Local variables
        integer :: i
        character(kind=c_char), dimension(:), pointer :: c_varname
        type (c_ptr) :: c_file
        type (c_ptr) :: c_decomp
        type (c_ptr) :: c_buf


        !
        ! file is a target, so no need to check that it is associated
        !
        c_file = c_loc(file)

        !
        ! decomp may be an unassociated pointer if the corresponding field is
        ! not decomposed
        !
        if (associated(decomp)) then
            c_decomp = c_loc(decomp)
        else
            c_decomp = c_null_ptr
        end if

        !
        ! Convert variable name string
        !
        allocate(c_varname(len_trim(varname) + 1))
        do i=1,len_trim(varname)
            c_varname(i) = varname(i:i)
        end do
        c_varname(i) = c_null_char

        !
        ! buf may be an unassociated pointer if the calling task does not read
        ! or write any elements of the field
        !
        if (associated(buf)) then

            !
            ! Invoke a Fortran 2003-compliant function to get the c_ptr
            ! of the assumed shape array buf
            !
            c_buf = c_loc_assumed_shape_2_2d_int32(buf, size(buf,dim=1), size(buf,dim=2))
        else
            c_buf = c_null_ptr
        end if

        ierr = SMIOL_put_var(c_file, c_varname, c_decomp, c_buf)


        deallocate(c_varname)

    end function SMIOLf_put_var_serialbox_2d_int32


 
    !-----------------------------------------------------------------------
    !  routine c_loc_assumed_shape_2_3d_real32
    !
    !> \brief Returns a C_PTR for an array with given dimensions
    !> \details
    !>  The Fortran 2003 standard does not permit the use of C_LOC with
    !>  assumed shape arrays. This routine may be used to obtain a C_PTR for
    !>  an assumed shape array by invoking the routine with the first actual
    !>  argument as the assumed-shape array, and subsequent actual arguments
    !>  as, e.g., SIZE(a,DIM=1).
    !>
    !>  Internally, the first dummy argument of this routine can be declared
    !>  as an explicit shape array, which can then be used as an argument to
    !>  C_LOC.
    !>
    !>  Upon success, a C_PTR for the array argument is returned.
    !>
    !>  Note: The actual array argument must not be a zero-sized array.
    !>        Section 15.1.2.5 of the Fortran 2003 standard specifies that
    !>        the argument to C_LOC '...is not an array of zero size...'.
    !
    !-----------------------------------------------------------------------
    function c_loc_assumed_shape_2_3d_real32(a, d1, d2, d3) result(a_ptr)

        use iso_c_binding, only : c_ptr, c_loc, c_float

        implicit none

        ! Arguments
        integer, intent(in) :: d1, d2, d3
        real(kind=c_float), dimension(d1,d2,d3), target, intent(in) :: a

        ! Return value
        type (c_ptr) :: a_ptr

        a_ptr = c_loc(a)

    end function c_loc_assumed_shape_2_3d_real32


    !-----------------------------------------------------------------------
    !  routine SMIOLf_put_var_serialbox_d3_real32
    !
    !> \brief Writes a 3-d real32 variable to a file.
    !> \details
    !>  Given a SMIOL file that was previously opened with write access and the name
    !>  of a variable previously defined in the file with a call to SMIOLf_define_var,
    !>  this routine will write the contents of buf to the variable according to
    !>  the decomposition described by decomp.
    !>
    !>  If decomp is an associated pointer, the variable is assumed to be decomposed
    !>  across MPI ranks, and all ranks with non-zero-sized partitions of the variable
    !>  must provide a valid buffer. For decomposed variables, all MPI ranks must provide
    !>  an associated decomp pointer, regardless of whether a rank has a non-zero-sized
    !>  partition of the variable.
    !>
    !>  If the variable is not decomposed -- that is, all ranks store identical
    !>  values for the entire variable -- all MPI ranks must provide an unassociated
    !>  pointer for the decomp argument. As currently implemented, this routine will write
    !>  the buffer for MPI rank 0 to the variable; however, this behavior should not
    !>  be relied on.
    !>
    !>  If the variable has been successfully written to the file, SMIOL_SUCCESS will
    !>  be returned. Otherwise, an error code indicating the nature of the failure
    !>  will be returned.
    !
    !-----------------------------------------------------------------------
    function SMIOLf_put_var_serialbox_3d_real32(serializer, savepoint, fieldname, &
                                    smiol_file, smiol_varname, decomp, buf) result(ierr)

        use iso_c_binding, only : c_float, c_char, c_loc, c_ptr, c_null_ptr, c_null_char
        use m_serialize

        implicit none

        ! Arguments
        TYPE(t_serializer), INTENT(IN)          :: serializer
        TYPE(t_savepoint) , INTENT(IN)          :: savepoint
        CHARACTER(LEN=*)  , intent(in)          :: fieldname
        type(SMIOLf_file), target :: smiol_file
        character(len=*), intent(in) :: smiol_varname
        type(SMIOLf_decomp), pointer :: decomp
        real(kind=RKIND), dimension(:,:,:), pointer :: buf

        ! Return status code
        integer :: ierr

        ! Local variables
        real(kind=c_float), dimension(:,:,:), pointer :: buf_1
        INTEGER(C_INT) :: c_type
        integer :: i
        character(kind=c_char), dimension(:), pointer :: c_varname
        type (c_ptr) :: c_file
        type (c_ptr) :: c_decomp
        type (c_ptr) :: c_buf

        print *,'inside SMIOLf_put_var_serialbox_3d_real32 '
      

        buf_1 => buf
        !
        ! file is a target, so no need to check that it is associated
        !
        c_file = c_loc(smiol_file)

        !
        ! decomp may be an unassociated pointer if the corresponding field is
        ! not decomposed
        !
        if (associated(decomp)) then
            c_decomp = c_loc(decomp)
        else
            c_decomp = c_null_ptr
        end if

        !
        ! Convert variable name string
        !
        allocate(c_varname(len_trim(smiol_varname) + 1))
        do i=1,len_trim(smiol_varname)
            c_varname(i) = smiol_varname(i:i)
        end do
        c_varname(i) = c_null_char

        !
        ! buf may be an unassociated pointer if the calling task does not read
        ! or write any elements of the field
        !
        if (associated(buf_1)) then

            !
            ! Invoke a Fortran 2003-compliant function to get the c_ptr
            ! of the assumed shape array buf
            !
            c_buf = c_loc_assumed_shape_2_3d_real32(buf, size(buf,dim=1), size(buf,dim=2), size(buf,dim=3))
        else
            c_buf = c_null_ptr
        end if

        c_type = 4
       
        ierr = SMIOL_put_var_serialbox(serializer%serializer_ptr, savepoint%savepoint_ptr, &
                                        TRIM(fieldname)//C_NULL_CHAR, c_type, &
                                        c_file, c_varname, c_decomp, c_buf)

        deallocate(c_varname)

    end function SMIOLf_put_var_serialbox_3d_real32



    !-----------------------------------------------------------------------
    !  routine c_loc_assumed_shape_2_3d_real64
    !
    !> \brief Returns a C_PTR for an array with given dimensions
    !> \details
    !>  The Fortran 2003 standard does not permit the use of C_LOC with
    !>  assumed shape arrays. This routine may be used to obtain a C_PTR for
    !>  an assumed shape array by invoking the routine with the first actual
    !>  argument as the assumed-shape array, and subsequent actual arguments
    !>  as, e.g., SIZE(a,DIM=1).
    !>
    !>  Internally, the first dummy argument of this routine can be declared
    !>  as an explicit shape array, which can then be used as an argument to
    !>  C_LOC.
    !>
    !>  Upon success, a C_PTR for the array argument is returned.
    !>
    !>  Note: The actual array argument must not be a zero-sized array.
    !>        Section 15.1.2.5 of the Fortran 2003 standard specifies that
    !>        the argument to C_LOC '...is not an array of zero size...'.
    !
    !-----------------------------------------------------------------------
    function c_loc_assumed_shape_2_3d_real64(a, d1, d2, d3) result(a_ptr)

        use iso_c_binding, only : c_ptr, c_loc, c_double

        implicit none

        ! Arguments
        integer, intent(in) :: d1, d2, d3
        real(kind=c_double), dimension(d1,d2,d3), target, intent(in) :: a

        ! Return value
        type (c_ptr) :: a_ptr

        a_ptr = c_loc(a)

    end function c_loc_assumed_shape_2_3d_real64


    !-----------------------------------------------------------------------
    !  routine SMIOLf_put_var_serialbox_d3_real64
    !
    !> \brief Writes a 3-d real64 variable to a file.
    !> \details
    !>  Given a SMIOL file that was previously opened with write access and the name
    !>  of a variable previously defined in the file with a call to SMIOLf_define_var,
    !>  this routine will write the contents of buf to the variable according to
    !>  the decomposition described by decomp.
    !>
    !>  If decomp is an associated pointer, the variable is assumed to be decomposed
    !>  across MPI ranks, and all ranks with non-zero-sized partitions of the variable
    !>  must provide a valid buffer. For decomposed variables, all MPI ranks must provide
    !>  an associated decomp pointer, regardless of whether a rank has a non-zero-sized
    !>  partition of the variable.
    !>
    !>  If the variable is not decomposed -- that is, all ranks store identical
    !>  values for the entire variable -- all MPI ranks must provide an unassociated
    !>  pointer for the decomp argument. As currently implemented, this routine will write
    !>  the buffer for MPI rank 0 to the variable; however, this behavior should not
    !>  be relied on.
    !>
    !>  If the variable has been successfully written to the file, SMIOL_SUCCESS will
    !>  be returned. Otherwise, an error code indicating the nature of the failure
    !>  will be returned.
    !
    !-----------------------------------------------------------------------
    function SMIOLf_put_var_serialbox_3d_real64(file, varname, decomp, buf) result(ierr)

        use iso_c_binding, only : c_double, c_char, c_loc, c_ptr, c_null_ptr, c_null_char

        implicit none

        ! Arguments
        type(SMIOLf_file), target :: file
        character(len=*), intent(in) :: varname
        type(SMIOLf_decomp), pointer :: decomp
        real(kind=c_double), dimension(:,:,:), pointer :: buf

        ! Return status code
        integer :: ierr

        ! Local variables
        integer :: i
        character(kind=c_char), dimension(:), pointer :: c_varname
        type (c_ptr) :: c_file
        type (c_ptr) :: c_decomp
        type (c_ptr) :: c_buf


        !
        ! file is a target, so no need to check that it is associated
        !
        c_file = c_loc(file)

        !
        ! decomp may be an unassociated pointer if the corresponding field is
        ! not decomposed
        !
        if (associated(decomp)) then
            c_decomp = c_loc(decomp)
        else
            c_decomp = c_null_ptr
        end if

        !
        ! Convert variable name string
        !
        allocate(c_varname(len_trim(varname) + 1))
        do i=1,len_trim(varname)
            c_varname(i) = varname(i:i)
        end do
        c_varname(i) = c_null_char

        !
        ! buf may be an unassociated pointer if the calling task does not read
        ! or write any elements of the field
        !
        if (associated(buf)) then

            !
            ! Invoke a Fortran 2003-compliant function to get the c_ptr
            ! of the assumed shape array buf
            !
            c_buf = c_loc_assumed_shape_2_3d_real64(buf, size(buf,dim=1), size(buf,dim=2), size(buf,dim=3))
        else
            c_buf = c_null_ptr
        end if

        ierr = SMIOL_put_var(c_file, c_varname, c_decomp, c_buf)


        deallocate(c_varname)

    end function SMIOLf_put_var_serialbox_3d_real64



    !-----------------------------------------------------------------------
    !  routine c_loc_assumed_shape_2_3d_int32
    !
    !> \brief Returns a C_PTR for an array with given dimensions
    !> \details
    !>  The Fortran 2003 standard does not permit the use of C_LOC with
    !>  assumed shape arrays. This routine may be used to obtain a C_PTR for
    !>  an assumed shape array by invoking the routine with the first actual
    !>  argument as the assumed-shape array, and subsequent actual arguments
    !>  as, e.g., SIZE(a,DIM=1).
    !>
    !>  Internally, the first dummy argument of this routine can be declared
    !>  as an explicit shape array, which can then be used as an argument to
    !>  C_LOC.
    !>
    !>  Upon success, a C_PTR for the array argument is returned.
    !>
    !>  Note: The actual array argument must not be a zero-sized array.
    !>        Section 15.1.2.5 of the Fortran 2003 standard specifies that
    !>        the argument to C_LOC '...is not an array of zero size...'.
    !
    !-----------------------------------------------------------------------
    function c_loc_assumed_shape_2_3d_int32(a, d1, d2, d3) result(a_ptr)

        use iso_c_binding, only : c_ptr, c_loc, c_int

        implicit none

        ! Arguments
        integer, intent(in) :: d1, d2, d3
        integer(kind=c_int), dimension(d1,d2,d3), target, intent(in) :: a

        ! Return value
        type (c_ptr) :: a_ptr

        a_ptr = c_loc(a)

    end function c_loc_assumed_shape_2_3d_int32


    !-----------------------------------------------------------------------
    !  routine SMIOLf_put_var_serialbox_d3_int32
    !
    !> \brief Writes a 3-d int32 variable to a file.
    !> \details
    !>  Given a SMIOL file that was previously opened with write access and the name
    !>  of a variable previously defined in the file with a call to SMIOLf_define_var,
    !>  this routine will write the contents of buf to the variable according to
    !>  the decomposition described by decomp.
    !>
    !>  If decomp is an associated pointer, the variable is assumed to be decomposed
    !>  across MPI ranks, and all ranks with non-zero-sized partitions of the variable
    !>  must provide a valid buffer. For decomposed variables, all MPI ranks must provide
    !>  an associated decomp pointer, regardless of whether a rank has a non-zero-sized
    !>  partition of the variable.
    !>
    !>  If the variable is not decomposed -- that is, all ranks store identical
    !>  values for the entire variable -- all MPI ranks must provide an unassociated
    !>  pointer for the decomp argument. As currently implemented, this routine will write
    !>  the buffer for MPI rank 0 to the variable; however, this behavior should not
    !>  be relied on.
    !>
    !>  If the variable has been successfully written to the file, SMIOL_SUCCESS will
    !>  be returned. Otherwise, an error code indicating the nature of the failure
    !>  will be returned.
    !
    !-----------------------------------------------------------------------
    function SMIOLf_put_var_serialbox_3d_int32(file, varname, decomp, buf) result(ierr)

        use iso_c_binding, only : c_int, c_char, c_loc, c_ptr, c_null_ptr, c_null_char

        implicit none

        ! Arguments
        type(SMIOLf_file), target :: file
        character(len=*), intent(in) :: varname
        type(SMIOLf_decomp), pointer :: decomp
        integer(kind=c_int), dimension(:,:,:), pointer :: buf

        ! Return status code
        integer :: ierr

        ! Local variables
        integer :: i
        character(kind=c_char), dimension(:), pointer :: c_varname
        type (c_ptr) :: c_file
        type (c_ptr) :: c_decomp
        type (c_ptr) :: c_buf


        !
        ! file is a target, so no need to check that it is associated
        !
        c_file = c_loc(file)

        !
        ! decomp may be an unassociated pointer if the corresponding field is
        ! not decomposed
        !
        if (associated(decomp)) then
            c_decomp = c_loc(decomp)
        else
            c_decomp = c_null_ptr
        end if

        !
        ! Convert variable name string
        !
        allocate(c_varname(len_trim(varname) + 1))
        do i=1,len_trim(varname)
            c_varname(i) = varname(i:i)
        end do
        c_varname(i) = c_null_char

        !
        ! buf may be an unassociated pointer if the calling task does not read
        ! or write any elements of the field
        !
        if (associated(buf)) then

            !
            ! Invoke a Fortran 2003-compliant function to get the c_ptr
            ! of the assumed shape array buf
            !
            c_buf = c_loc_assumed_shape_2_3d_int32(buf, size(buf,dim=1), size(buf,dim=2), size(buf,dim=3))
        else
            c_buf = c_null_ptr
        end if

        ierr = SMIOL_put_var(c_file, c_varname, c_decomp, c_buf)


        deallocate(c_varname)

    end function SMIOLf_put_var_serialbox_3d_int32


    !-----------------------------------------------------------------------
    !  routine c_loc_assumed_shape_2_4d_real32
    !
    !> \brief Returns a C_PTR for an array with given dimensions
    !> \details
    !>  The Fortran 2003 standard does not permit the use of C_LOC with
    !>  assumed shape arrays. This routine may be used to obtain a C_PTR for
    !>  an assumed shape array by invoking the routine with the first actual
    !>  argument as the assumed-shape array, and subsequent actual arguments
    !>  as, e.g., SIZE(a,DIM=1).
    !>
    !>  Internally, the first dummy argument of this routine can be declared
    !>  as an explicit shape array, which can then be used as an argument to
    !>  C_LOC.
    !>
    !>  Upon success, a C_PTR for the array argument is returned.
    !>
    !>  Note: The actual array argument must not be a zero-sized array.
    !>        Section 15.1.2.5 of the Fortran 2003 standard specifies that
    !>        the argument to C_LOC '...is not an array of zero size...'.
    !
    !-----------------------------------------------------------------------
    function c_loc_assumed_shape_2_4d_real32(a, d1, d2, d3, d4) result(a_ptr)

        use iso_c_binding, only : c_ptr, c_loc, c_float

        implicit none

        ! Arguments
        integer, intent(in) :: d1, d2, d3, d4
        real(kind=c_float), dimension(d1,d2,d3,d4), target, intent(in) :: a

        ! Return value
        type (c_ptr) :: a_ptr

        a_ptr = c_loc(a)

    end function c_loc_assumed_shape_2_4d_real32


    !-----------------------------------------------------------------------
    !  routine SMIOLf_put_var_serialbox_d4_real32
    !
    !> \brief Writes a 4-d real32 variable to a file.
    !> \details
    !>  Given a SMIOL file that was previously opened with write access and the name
    !>  of a variable previously defined in the file with a call to SMIOLf_define_var,
    !>  this routine will write the contents of buf to the variable according to
    !>  the decomposition described by decomp.
    !>
    !>  If decomp is an associated pointer, the variable is assumed to be decomposed
    !>  across MPI ranks, and all ranks with non-zero-sized partitions of the variable
    !>  must provide a valid buffer. For decomposed variables, all MPI ranks must provide
    !>  an associated decomp pointer, regardless of whether a rank has a non-zero-sized
    !>  partition of the variable.
    !>
    !>  If the variable is not decomposed -- that is, all ranks store identical
    !>  values for the entire variable -- all MPI ranks must provide an unassociated
    !>  pointer for the decomp argument. As currently implemented, this routine will write
    !>  the buffer for MPI rank 0 to the variable; however, this behavior should not
    !>  be relied on.
    !>
    !>  If the variable has been successfully written to the file, SMIOL_SUCCESS will
    !>  be returned. Otherwise, an error code indicating the nature of the failure
    !>  will be returned.
    !
    !-----------------------------------------------------------------------
    function SMIOLf_put_var_serialbox_4d_real32(file, varname, decomp, buf) result(ierr)

        use iso_c_binding, only : c_float, c_char, c_loc, c_ptr, c_null_ptr, c_null_char

        implicit none

        ! Arguments
        type(SMIOLf_file), target :: file
        character(len=*), intent(in) :: varname
        type(SMIOLf_decomp), pointer :: decomp
        real(kind=c_float), dimension(:,:,:,:), pointer :: buf

        ! Return status code
        integer :: ierr

        ! Local variables
        integer :: i
        character(kind=c_char), dimension(:), pointer :: c_varname
        type (c_ptr) :: c_file
        type (c_ptr) :: c_decomp
        type (c_ptr) :: c_buf


        !
        ! file is a target, so no need to check that it is associated
        !
        c_file = c_loc(file)

        !
        ! decomp may be an unassociated pointer if the corresponding field is
        ! not decomposed
        !
        if (associated(decomp)) then
            c_decomp = c_loc(decomp)
        else
            c_decomp = c_null_ptr
        end if

        !
        ! Convert variable name string
        !
        allocate(c_varname(len_trim(varname) + 1))
        do i=1,len_trim(varname)
            c_varname(i) = varname(i:i)
        end do
        c_varname(i) = c_null_char

        !
        ! buf may be an unassociated pointer if the calling task does not read
        ! or write any elements of the field
        !
        if (associated(buf)) then

            !
            ! Invoke a Fortran 2003-compliant function to get the c_ptr
            ! of the assumed shape array buf
            !
            c_buf = c_loc_assumed_shape_2_4d_real32(buf, size(buf,dim=1), size(buf,dim=2), size(buf,dim=3), &
                                           size(buf,dim=4))
        else
            c_buf = c_null_ptr
        end if

        ierr = SMIOL_put_var(c_file, c_varname, c_decomp, c_buf)


        deallocate(c_varname)

    end function SMIOLf_put_var_serialbox_4d_real32


 
    !-----------------------------------------------------------------------
    !  routine c_loc_assumed_shape_2_4d_real64
    !
    !> \brief Returns a C_PTR for an array with given dimensions
    !> \details
    !>  The Fortran 2003 standard does not permit the use of C_LOC with
    !>  assumed shape arrays. This routine may be used to obtain a C_PTR for
    !>  an assumed shape array by invoking the routine with the first actual
    !>  argument as the assumed-shape array, and subsequent actual arguments
    !>  as, e.g., SIZE(a,DIM=1).
    !>
    !>  Internally, the first dummy argument of this routine can be declared
    !>  as an explicit shape array, which can then be used as an argument to
    !>  C_LOC.
    !>
    !>  Upon success, a C_PTR for the array argument is returned.
    !>
    !>  Note: The actual array argument must not be a zero-sized array.
    !>        Section 15.1.2.5 of the Fortran 2003 standard specifies that
    !>        the argument to C_LOC '...is not an array of zero size...'.
    !
    !-----------------------------------------------------------------------
    function c_loc_assumed_shape_2_4d_real64(a, d1, d2, d3, d4) result(a_ptr)

        use iso_c_binding, only : c_ptr, c_loc, c_double

        implicit none

        ! Arguments
        integer, intent(in) :: d1, d2, d3, d4
        real(kind=c_double), dimension(d1,d2,d3,d4), target, intent(in) :: a

        ! Return value
        type (c_ptr) :: a_ptr

        a_ptr = c_loc(a)

    end function c_loc_assumed_shape_2_4d_real64


    !-----------------------------------------------------------------------
    !  routine SMIOLf_put_var_serialbox_d4_real64
    !
    !> \brief Writes a 4-d real64 variable to a file.
    !> \details
    !>  Given a SMIOL file that was previously opened with write access and the name
    !>  of a variable previously defined in the file with a call to SMIOLf_define_var,
    !>  this routine will write the contents of buf to the variable according to
    !>  the decomposition described by decomp.
    !>
    !>  If decomp is an associated pointer, the variable is assumed to be decomposed
    !>  across MPI ranks, and all ranks with non-zero-sized partitions of the variable
    !>  must provide a valid buffer. For decomposed variables, all MPI ranks must provide
    !>  an associated decomp pointer, regardless of whether a rank has a non-zero-sized
    !>  partition of the variable.
    !>
    !>  If the variable is not decomposed -- that is, all ranks store identical
    !>  values for the entire variable -- all MPI ranks must provide an unassociated
    !>  pointer for the decomp argument. As currently implemented, this routine will write
    !>  the buffer for MPI rank 0 to the variable; however, this behavior should not
    !>  be relied on.
    !>
    !>  If the variable has been successfully written to the file, SMIOL_SUCCESS will
    !>  be returned. Otherwise, an error code indicating the nature of the failure
    !>  will be returned.
    !
    !-----------------------------------------------------------------------
    function SMIOLf_put_var_serialbox_4d_real64(file, varname, decomp, buf) result(ierr)

        use iso_c_binding, only : c_double, c_char, c_loc, c_ptr, c_null_ptr, c_null_char

        implicit none

        ! Arguments
        type(SMIOLf_file), target :: file
        character(len=*), intent(in) :: varname
        type(SMIOLf_decomp), pointer :: decomp
        real(kind=c_double), dimension(:,:,:,:), pointer :: buf

        ! Return status code
        integer :: ierr

        ! Local variables
        integer :: i
        character(kind=c_char), dimension(:), pointer :: c_varname
        type (c_ptr) :: c_file
        type (c_ptr) :: c_decomp
        type (c_ptr) :: c_buf


        !
        ! file is a target, so no need to check that it is associated
        !
        c_file = c_loc(file)

        !
        ! decomp may be an unassociated pointer if the corresponding field is
        ! not decomposed
        !
        if (associated(decomp)) then
            c_decomp = c_loc(decomp)
        else
            c_decomp = c_null_ptr
        end if

        !
        ! Convert variable name string
        !
        allocate(c_varname(len_trim(varname) + 1))
        do i=1,len_trim(varname)
            c_varname(i) = varname(i:i)
        end do
        c_varname(i) = c_null_char

        !
        ! buf may be an unassociated pointer if the calling task does not read
        ! or write any elements of the field
        !
        if (associated(buf)) then

            !
            ! Invoke a Fortran 2003-compliant function to get the c_ptr
            ! of the assumed shape array buf
            !
            c_buf = c_loc_assumed_shape_2_4d_real64(buf, size(buf,dim=1), size(buf,dim=2), size(buf,dim=3), &
                                           size(buf,dim=4))
        else
            c_buf = c_null_ptr
        end if

        ierr = SMIOL_put_var(c_file, c_varname, c_decomp, c_buf)


        deallocate(c_varname)

    end function SMIOLf_put_var_serialbox_4d_real64



    !-----------------------------------------------------------------------
    !  routine c_loc_assumed_shape_2_4d_int32
    !
    !> \brief Returns a C_PTR for an array with given dimensions
    !> \details
    !>  The Fortran 2003 standard does not permit the use of C_LOC with
    !>  assumed shape arrays. This routine may be used to obtain a C_PTR for
    !>  an assumed shape array by invoking the routine with the first actual
    !>  argument as the assumed-shape array, and subsequent actual arguments
    !>  as, e.g., SIZE(a,DIM=1).
    !>
    !>  Internally, the first dummy argument of this routine can be declared
    !>  as an explicit shape array, which can then be used as an argument to
    !>  C_LOC.
    !>
    !>  Upon success, a C_PTR for the array argument is returned.
    !>
    !>  Note: The actual array argument must not be a zero-sized array.
    !>        Section 15.1.2.5 of the Fortran 2003 standard specifies that
    !>        the argument to C_LOC '...is not an array of zero size...'.
    !
    !-----------------------------------------------------------------------
    function c_loc_assumed_shape_2_4d_int32(a, d1, d2, d3, d4) result(a_ptr)

        use iso_c_binding, only : c_ptr, c_loc, c_int

        implicit none

        ! Arguments
        integer, intent(in) :: d1, d2, d3, d4
        integer(kind=c_int), dimension(d1,d2,d3,d4), target, intent(in) :: a

        ! Return value
        type (c_ptr) :: a_ptr

        a_ptr = c_loc(a)

    end function c_loc_assumed_shape_2_4d_int32


    !-----------------------------------------------------------------------
    !  routine SMIOLf_put_var_serialbox_d4_int32
    !
    !> \brief Writes a 4-d int32 variable to a file.
    !> \details
    !>  Given a SMIOL file that was previously opened with write access and the name
    !>  of a variable previously defined in the file with a call to SMIOLf_define_var,
    !>  this routine will write the contents of buf to the variable according to
    !>  the decomposition described by decomp.
    !>
    !>  If decomp is an associated pointer, the variable is assumed to be decomposed
    !>  across MPI ranks, and all ranks with non-zero-sized partitions of the variable
    !>  must provide a valid buffer. For decomposed variables, all MPI ranks must provide
    !>  an associated decomp pointer, regardless of whether a rank has a non-zero-sized
    !>  partition of the variable.
    !>
    !>  If the variable is not decomposed -- that is, all ranks store identical
    !>  values for the entire variable -- all MPI ranks must provide an unassociated
    !>  pointer for the decomp argument. As currently implemented, this routine will write
    !>  the buffer for MPI rank 0 to the variable; however, this behavior should not
    !>  be relied on.
    !>
    !>  If the variable has been successfully written to the file, SMIOL_SUCCESS will
    !>  be returned. Otherwise, an error code indicating the nature of the failure
    !>  will be returned.
    !
    !-----------------------------------------------------------------------
    function SMIOLf_put_var_serialbox_4d_int32(file, varname, decomp, buf) result(ierr)

        use iso_c_binding, only : c_int, c_char, c_loc, c_ptr, c_null_ptr, c_null_char

        implicit none

        ! Arguments
        type(SMIOLf_file), target :: file
        character(len=*), intent(in) :: varname
        type(SMIOLf_decomp), pointer :: decomp
        integer(kind=c_int), dimension(:,:,:,:), pointer :: buf

        ! Return status code
        integer :: ierr

        ! Local variables
        integer :: i
        character(kind=c_char), dimension(:), pointer :: c_varname
        type (c_ptr) :: c_file
        type (c_ptr) :: c_decomp
        type (c_ptr) :: c_buf


        !
        ! file is a target, so no need to check that it is associated
        !
        c_file = c_loc(file)

        !
        ! decomp may be an unassociated pointer if the corresponding field is
        ! not decomposed
        !
        if (associated(decomp)) then
            c_decomp = c_loc(decomp)
        else
            c_decomp = c_null_ptr
        end if

        !
        ! Convert variable name string
        !
        allocate(c_varname(len_trim(varname) + 1))
        do i=1,len_trim(varname)
            c_varname(i) = varname(i:i)
        end do
        c_varname(i) = c_null_char

        !
        ! buf may be an unassociated pointer if the calling task does not read
        ! or write any elements of the field
        !
        if (associated(buf)) then

            !
            ! Invoke a Fortran 2003-compliant function to get the c_ptr
            ! of the assumed shape array buf
            !
            c_buf = c_loc_assumed_shape_2_4d_int32(buf, size(buf,dim=1), size(buf,dim=2), size(buf,dim=3), &
                                           size(buf,dim=4))
        else
            c_buf = c_null_ptr
        end if

        ierr = SMIOL_put_var(c_file, c_varname, c_decomp, c_buf)


        deallocate(c_varname)

    end function SMIOLf_put_var_serialbox_4d_int32


 
    !-----------------------------------------------------------------------
    !  routine c_loc_assumed_shape_2_5d_real32
    !
    !> \brief Returns a C_PTR for an array with given dimensions
    !> \details
    !>  The Fortran 2003 standard does not permit the use of C_LOC with
    !>  assumed shape arrays. This routine may be used to obtain a C_PTR for
    !>  an assumed shape array by invoking the routine with the first actual
    !>  argument as the assumed-shape array, and subsequent actual arguments
    !>  as, e.g., SIZE(a,DIM=1).
    !>
    !>  Internally, the first dummy argument of this routine can be declared
    !>  as an explicit shape array, which can then be used as an argument to
    !>  C_LOC.
    !>
    !>  Upon success, a C_PTR for the array argument is returned.
    !>
    !>  Note: The actual array argument must not be a zero-sized array.
    !>        Section 15.1.2.5 of the Fortran 2003 standard specifies that
    !>        the argument to C_LOC '...is not an array of zero size...'.
    !
    !-----------------------------------------------------------------------
    function c_loc_assumed_shape_2_5d_real32(a, d1, d2, d3, d4, d5) result(a_ptr)

        use iso_c_binding, only : c_ptr, c_loc, c_float

        implicit none

        ! Arguments
        integer, intent(in) :: d1, d2, d3, d4, d5
        real(kind=c_float), dimension(d1,d2,d3,d4,d5), target, intent(in) :: a

        ! Return value
        type (c_ptr) :: a_ptr

        a_ptr = c_loc(a)

    end function c_loc_assumed_shape_2_5d_real32


    !-----------------------------------------------------------------------
    !  routine SMIOLf_put_var_serialbox_d5_real32
    !
    !> \brief Writes a 5-d real32 variable to a file.
    !> \details
    !>  Given a SMIOL file that was previously opened with write access and the name
    !>  of a variable previously defined in the file with a call to SMIOLf_define_var,
    !>  this routine will write the contents of buf to the variable according to
    !>  the decomposition described by decomp.
    !>
    !>  If decomp is an associated pointer, the variable is assumed to be decomposed
    !>  across MPI ranks, and all ranks with non-zero-sized partitions of the variable
    !>  must provide a valid buffer. For decomposed variables, all MPI ranks must provide
    !>  an associated decomp pointer, regardless of whether a rank has a non-zero-sized
    !>  partition of the variable.
    !>
    !>  If the variable is not decomposed -- that is, all ranks store identical
    !>  values for the entire variable -- all MPI ranks must provide an unassociated
    !>  pointer for the decomp argument. As currently implemented, this routine will write
    !>  the buffer for MPI rank 0 to the variable; however, this behavior should not
    !>  be relied on.
    !>
    !>  If the variable has been successfully written to the file, SMIOL_SUCCESS will
    !>  be returned. Otherwise, an error code indicating the nature of the failure
    !>  will be returned.
    !
    !-----------------------------------------------------------------------
    function SMIOLf_put_var_serialbox_5d_real32(file, varname, decomp, buf) result(ierr)

        use iso_c_binding, only : c_float, c_char, c_loc, c_ptr, c_null_ptr, c_null_char

        implicit none

        ! Arguments
        type(SMIOLf_file), target :: file
        character(len=*), intent(in) :: varname
        type(SMIOLf_decomp), pointer :: decomp
        real(kind=c_float), dimension(:,:,:,:,:), pointer :: buf

        ! Return status code
        integer :: ierr

        ! Local variables
        integer :: i
        character(kind=c_char), dimension(:), pointer :: c_varname
        type (c_ptr) :: c_file
        type (c_ptr) :: c_decomp
        type (c_ptr) :: c_buf


        !
        ! file is a target, so no need to check that it is associated
        !
        c_file = c_loc(file)

        !
        ! decomp may be an unassociated pointer if the corresponding field is
        ! not decomposed
        !
        if (associated(decomp)) then
            c_decomp = c_loc(decomp)
        else
            c_decomp = c_null_ptr
        end if

        !
        ! Convert variable name string
        !
        allocate(c_varname(len_trim(varname) + 1))
        do i=1,len_trim(varname)
            c_varname(i) = varname(i:i)
        end do
        c_varname(i) = c_null_char

        !
        ! buf may be an unassociated pointer if the calling task does not read
        ! or write any elements of the field
        !
        if (associated(buf)) then

            !
            ! Invoke a Fortran 2003-compliant function to get the c_ptr
            ! of the assumed shape array buf
            !
            c_buf = c_loc_assumed_shape_2_5d_real32(buf, size(buf,dim=1), size(buf,dim=2), size(buf,dim=3), &
                                           size(buf,dim=4), size(buf,dim=5))
        else
            c_buf = c_null_ptr
        end if

        ierr = SMIOL_put_var(c_file, c_varname, c_decomp, c_buf)


        deallocate(c_varname)

    end function SMIOLf_put_var_serialbox_5d_real32


    !-----------------------------------------------------------------------
    !  routine c_loc_assumed_shape_2_5d_real64
    !
    !> \brief Returns a C_PTR for an array with given dimensions
    !> \details
    !>  The Fortran 2003 standard does not permit the use of C_LOC with
    !>  assumed shape arrays. This routine may be used to obtain a C_PTR for
    !>  an assumed shape array by invoking the routine with the first actual
    !>  argument as the assumed-shape array, and subsequent actual arguments
    !>  as, e.g., SIZE(a,DIM=1).
    !>
    !>  Internally, the first dummy argument of this routine can be declared
    !>  as an explicit shape array, which can then be used as an argument to
    !>  C_LOC.
    !>
    !>  Upon success, a C_PTR for the array argument is returned.
    !>
    !>  Note: The actual array argument must not be a zero-sized array.
    !>        Section 15.1.2.5 of the Fortran 2003 standard specifies that
    !>        the argument to C_LOC '...is not an array of zero size...'.
    !
    !-----------------------------------------------------------------------
    function c_loc_assumed_shape_2_5d_real64(a, d1, d2, d3, d4, d5) result(a_ptr)

        use iso_c_binding, only : c_ptr, c_loc, c_double

        implicit none

        ! Arguments
        integer, intent(in) :: d1, d2, d3, d4, d5
        real(kind=c_double), dimension(d1,d2,d3,d4,d5), target, intent(in) :: a

        ! Return value
        type (c_ptr) :: a_ptr

        a_ptr = c_loc(a)

    end function c_loc_assumed_shape_2_5d_real64


    !-----------------------------------------------------------------------
    !  routine SMIOLf_put_var_serialbox_d5_real64
    !
    !> \brief Writes a 5-d real64 variable to a file.
    !> \details
    !>  Given a SMIOL file that was previously opened with write access and the name
    !>  of a variable previously defined in the file with a call to SMIOLf_define_var,
    !>  this routine will write the contents of buf to the variable according to
    !>  the decomposition described by decomp.
    !>
    !>  If decomp is an associated pointer, the variable is assumed to be decomposed
    !>  across MPI ranks, and all ranks with non-zero-sized partitions of the variable
    !>  must provide a valid buffer. For decomposed variables, all MPI ranks must provide
    !>  an associated decomp pointer, regardless of whether a rank has a non-zero-sized
    !>  partition of the variable.
    !>
    !>  If the variable is not decomposed -- that is, all ranks store identical
    !>  values for the entire variable -- all MPI ranks must provide an unassociated
    !>  pointer for the decomp argument. As currently implemented, this routine will write
    !>  the buffer for MPI rank 0 to the variable; however, this behavior should not
    !>  be relied on.
    !>
    !>  If the variable has been successfully written to the file, SMIOL_SUCCESS will
    !>  be returned. Otherwise, an error code indicating the nature of the failure
    !>  will be returned.
    !
    !-----------------------------------------------------------------------
    function SMIOLf_put_var_serialbox_5d_real64(file, varname, decomp, buf) result(ierr)

        use iso_c_binding, only : c_double, c_char, c_loc, c_ptr, c_null_ptr, c_null_char

        implicit none

        ! Arguments
        type(SMIOLf_file), target :: file
        character(len=*), intent(in) :: varname
        type(SMIOLf_decomp), pointer :: decomp
        real(kind=c_double), dimension(:,:,:,:,:), pointer :: buf

        ! Return status code
        integer :: ierr

        ! Local variables
        integer :: i
        character(kind=c_char), dimension(:), pointer :: c_varname
        type (c_ptr) :: c_file
        type (c_ptr) :: c_decomp
        type (c_ptr) :: c_buf


        !
        ! file is a target, so no need to check that it is associated
        !
        c_file = c_loc(file)

        !
        ! decomp may be an unassociated pointer if the corresponding field is
        ! not decomposed
        !
        if (associated(decomp)) then
            c_decomp = c_loc(decomp)
        else
            c_decomp = c_null_ptr
        end if

        !
        ! Convert variable name string
        !
        allocate(c_varname(len_trim(varname) + 1))
        do i=1,len_trim(varname)
            c_varname(i) = varname(i:i)
        end do
        c_varname(i) = c_null_char

        !
        ! buf may be an unassociated pointer if the calling task does not read
        ! or write any elements of the field
        !
        if (associated(buf)) then

            !
            ! Invoke a Fortran 2003-compliant function to get the c_ptr
            ! of the assumed shape array buf
            !
            c_buf = c_loc_assumed_shape_2_5d_real64(buf, size(buf,dim=1), size(buf,dim=2), size(buf,dim=3), &
                                           size(buf,dim=4), size(buf,dim=5))
        else
            c_buf = c_null_ptr
        end if

        ierr = SMIOL_put_var(c_file, c_varname, c_decomp, c_buf)


        deallocate(c_varname)

    end function SMIOLf_put_var_serialbox_5d_real64

