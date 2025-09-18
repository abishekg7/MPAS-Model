
module mpas_ptscotch_interface
    use iso_c_binding, only : c_int, c_double
#include "ptscotchf.h"
    public :: scotch_dgraphinit, scotch_dgraphbuild

    type, bind(c) :: my_scotch_graph_type
      real(c_double) :: dummy (29)
   end type


type(my_scotch_graph_type), pointer :: my_scotch_dgraph => null()

    
contains

    function scotch_dgraphinit(dgraph, comm) result(ierr)
        use iso_c_binding, only : c_ptr, c_int, c_loc
        use mpas_log, only : mpas_log_write
! #ifdef MPAS_USE_MPI_F08
!         use mpi_f08, only : MPI_Comm
! #endif

        implicit none
        ! Arguments
        doubleprecision, target, intent(in) :: dgraph (29)
! #ifdef MPAS_USE_MPI_F08
!         type (MPI_Comm), intent(in) :: comm
! #else
        integer, intent(in) :: comm
! #endif

        ! Return value
        integer :: ierr
        integer :: i
        type(c_ptr) :: dgraph_ptr

        interface
            function scotchfdgraphinit(dgraph_ptr_1, localcomm) bind(C, name='scotchm_dgraphinit') result(err)
            !function scotchfdgraphinit(localcomm) bind(C, name='scotchm_dgraphinit') result(err)
                use iso_c_binding, only : c_ptr, c_int, c_double
                !real(c_double), intent(in) :: dgraph_ptr_1 (29)
                type(c_ptr), value :: dgraph_ptr_1
                integer, intent(in), value :: localcomm
                integer(kind=c_int) :: err
            end function scotchfdgraphinit
        end interface


        ierr = 0
        !allocate(my_scotch_dgraph)

        !my_scotch_dgraph%dummy[0] = -1

        !dgraph_ptr = c_loc(my_scotch_dgraph)

        call mpas_log_write('Initializing Distributed Scotch Graph')
! #ifdef MPAS_USE_MPI_F08
!         ierr = scotchfdgraphinit(dgraph_ptr, comm % mpi_val)
! #else
        ierr = scotchfdgraphinit(c_loc(dgraph), comm)
        !ierr = scotchfdgraphinit(c_loc(my_scotch_dgraph), comm)
        !ierr = scotchfdgraphinit(comm)
!#endif

    end function scotch_dgraphinit


    function scotch_dgraphbuild(dgraph, nVertices, vertloctab, nLocEdgesGraph, edgelocsiz, adjncy) result(ierr)

        use iso_c_binding, only : c_ptr, c_int, c_loc
        use mpas_log, only : mpas_log_write
        use mpas_c_interfacing, only : mpas_f_to_c_string
        use iso_c_binding, only : c_char, c_associated

        implicit none

        doubleprecision, target, intent(in) :: dgraph (29)
        integer, intent(in) :: nVertices
        integer, intent(in) :: vertloctab(nVertices+1)
        integer, intent(in) :: nLocEdgesGraph
        integer, intent(in) :: edgelocsiz
        integer, intent(in) :: adjncy(nLocEdgesGraph)


        ! Return value
        integer :: ierr
        type(c_ptr) :: dgraph_ptr

        interface
            function scotchfdgraphbuild(dgraph_ptr_1, nVertices, vertloctab, &
                nLocEdgesGraph, edgelocsiz, adjncy) bind(C, name='scotchm_dgraphbuild') result(err)
                use iso_c_binding, only : c_ptr, c_int
                type(c_ptr), value :: dgraph_ptr_1
                integer, intent(in), value :: nVertices
                integer(c_int) :: vertloctab(nVertices+1)
                integer, intent(in), value :: nLocEdgesGraph
                integer, intent(in), value :: edgelocsiz
                integer(c_int) :: adjncy(nLocEdgesGraph)
                integer(kind=c_int) :: err
            end function scotchfdgraphbuild
        end interface


        ierr = 0
        !dgraph_ptr = c_loc(dgraph(1))

        call mpas_log_write('Building Distributed Scotch Graph')

        ierr = scotchfdgraphbuild(c_loc(dgraph), nVertices, vertloctab,  &   
                                  nLocEdgesGraph, edgelocsiz, adjncy)


    end function scotch_dgraphbuild



    function scotch_dgraphcheck(dgraph) result(ierr)

        use mpas_log, only : mpas_log_write
        use iso_c_binding, only : c_ptr, c_int, c_loc
        use iso_c_binding, only : c_char, c_associated

        implicit none

        doubleprecision, target, intent(in) :: dgraph (SCOTCH_DGRAPHDIM)

        ! Return value
        integer :: ierr
        type(c_ptr) :: dgraph_ptr

        interface
            function scotchfdgraphcheck(dgraph_ptr_1) bind(C, name='scotchm_dgraphcheck') result(err)
                use iso_c_binding, only : c_int, c_ptr
                type(c_ptr), value :: dgraph_ptr_1
                integer(kind=c_int) :: err
            end function scotchfdgraphcheck
        end interface


        ierr = 0

        dgraph_ptr = c_loc(dgraph(1))

        call mpas_log_write('Checking Distributed Scotch Graph')

        ierr = scotchfdgraphcheck(c_loc(dgraph))


    end function scotch_dgraphcheck


     function scotch_dgraphexit(dgraph) result(ierr)

        use mpas_log, only : mpas_log_write
        use iso_c_binding, only : c_ptr, c_int, c_loc

        implicit none

        doubleprecision, target, intent(in) :: dgraph (SCOTCH_DGRAPHDIM)

        ! Return value
        integer :: ierr
        type(c_ptr) :: dgraph_ptr

        interface
            function scotchfdgraphexit(dgraph_ptr_1) bind(C, name='scotchm_dgraphexit') result(err)
                use iso_c_binding, only : c_int, c_ptr
                type(c_ptr) :: dgraph_ptr_1
                integer(kind=c_int) :: err
            end function scotchfdgraphexit
        end interface


        ierr = 0

        dgraph_ptr = c_loc(dgraph(1))

        call mpas_log_write('Checking Distributed Scotch Graph')

        ierr = scotchfdgraphexit(dgraph_ptr)


    end function scotch_dgraphexit


    function scotch_stratinit(stradat) result(ierr)

        use mpas_log, only : mpas_log_write
        use iso_c_binding, only : c_ptr, c_int, c_loc
        use iso_c_binding, only : c_char, c_associated

        implicit none

        doubleprecision, target, intent(in) :: stradat (scotch_stratdim)
        

        ! Return value
        integer :: ierr
        type(c_ptr) :: dgraph_ptr

        interface
            function scotchfstratinit(strat_ptr_1) bind(C, name='scotchm_stratinit') result(err)
                use iso_c_binding, only : c_int, c_ptr
                type(c_ptr), value :: strat_ptr_1
                integer(kind=c_int) :: err
            end function scotchfstratinit
        end interface


        ierr = 0

        call mpas_log_write('Checking Distributed Scotch Graph')

        ierr = scotchfstratinit(c_loc(stradat))


    end function scotch_stratinit

    
        function scotch_dgraphpart(dgraph, num_part, stradat, parttab) result(ierr)

        use mpas_log, only : mpas_log_write
        use iso_c_binding, only : c_ptr, c_int, c_loc
        use iso_c_binding, only : c_char, c_associated

        implicit none

        doubleprecision, target, intent(in) :: dgraph (SCOTCH_DGRAPHDIM)
        integer, intent(in) :: num_part
        doubleprecision, target, intent(in) :: stradat (scotch_stratdim)
        integer, intent(out) :: parttab(*)
        

        ! Return value
        integer :: ierr
        type(c_ptr) :: dgraph_ptr

        interface
            function scotchfdgraphpart(dgraph_ptr, num_part, strat_ptr_1, parttab ) bind(C, name='scotchm_dgraphpart') result(err)
                use iso_c_binding, only : c_int, c_ptr
                type(c_ptr), value :: dgraph_ptr
                integer, intent(in), value :: num_part
                type(c_ptr), value :: strat_ptr_1
                integer(c_int) :: parttab(*)
                integer(kind=c_int) :: err
            end function scotchfdgraphpart
        end interface


        ierr = 0

        call mpas_log_write('Checking Distributed Scotch Graph')

        ierr = scotchfdgraphpart(c_loc(my_scotch_dgraph), num_part, c_loc(stradat), parttab)


    end function scotch_dgraphpart



end module mpas_ptscotch_interface
