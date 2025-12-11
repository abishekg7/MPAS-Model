#ifdef MPAS_SCOTCH
module mpas_ptscotch_interface
    use iso_c_binding, only : c_int, c_double
#include "ptscotchf.h"
    public :: scotch_dgraphinit, scotch_dgraphbuild

    

contains

    !-----------------------------------------------------------------------
    !  function scotch_dgraphinit
    !
    !> \brief Initialize a SCOTCH distributed graph object
    !> \author Abishek Gopal
    !> \date   8 Dec 2025
    !> \details
    !>  Initializes a SCOTCH_Dgraph structure using a Fortran MPI communicator.
    !>  This function wraps the C function scotchm_dgraphinit.
    !>  Returns an error code (0 if successful)
    !> \arguments
    !>   dgraph - SCOTCH_Dgraph structure to be initialized
    !>   comm   - Fortran MPI communicator integer
    !
    !-----------------------------------------------------------------------
    function scotch_dgraphinit(dgraph, comm) result(ierr)
        use iso_c_binding, only : c_ptr, c_loc
        use mpas_log, only : mpas_log_write
        use mpas_derived_types, only : MPAS_LOG_CRIT

        implicit none
        ! Arguments
        doubleprecision, target, intent(in) :: dgraph (SCOTCH_DGRAPHDIM)
        integer, intent(in) :: comm

        ! Return value
        integer :: ierr

        interface
            function scotchfdgraphinit(dgraph_ptr, localcomm) bind(C, name='scotchm_dgraphinit') result(err)
                use iso_c_binding, only : c_ptr, c_int
                type(c_ptr), value :: dgraph_ptr
                integer(c_int), value :: localcomm
                integer(c_int) :: err
            end function scotchfdgraphinit
        end interface

        ierr = scotchfdgraphinit(c_loc(dgraph), comm)

        if (ierr /= 0) then
            call mpas_log_write('Error initalizing distributed Scotch graph')
        else 
            call mpas_log_write('Successfully initialized distributed Scotch graph')    
        end if

    end function scotch_dgraphinit

    !-----------------------------------------------------------------------
    !  function scotch_dgraphbuild
    !
    !> \brief Build a SCOTCH distributed graph from local vertex/edge arrays
    !> \author Abishek Gopal
    !> \date   8 Dec 2025
    !> \details
    !>  Constructs a SCOTCH_Dgraph from local vertex and edge connectivity data.
    !>  This function wraps the C function scotchm_dgraphbuild, and returns an 
    !>  error code (0 if successful).
    !> \arguments
    !>   dgraph         - SCOTCH_Dgraph structure to be built
    !>   nVertices      - Number of local vertices
    !>   vertloctab     - Array of size (nVertices+1)
    !>                     giving the start index of edges for each local vertex
    !>   nLocEdgesGraph - Total number of local edges in the graph
    !>   edgelocsiz     - Size of the adjncy array
    !>   adjncy         - Array of size nLocEdgesGraph containing the  
    !>                     adjacency list for local vertices
    !
    !-----------------------------------------------------------------------
    function scotch_dgraphbuild(dgraph, nVertices, vertloctab, nLocEdgesGraph, edgelocsiz, adjncy) result(ierr)        
        use iso_c_binding, only : c_ptr, c_loc
        use mpas_log, only : mpas_log_write
        use mpas_derived_types, only : MPAS_LOG_CRIT

        implicit none

        doubleprecision, target, intent(in) :: dgraph (SCOTCH_DGRAPHDIM)
        integer(SCOTCH_NUMSIZE), intent(in) :: nVertices
        integer(SCOTCH_NUMSIZE), intent(in) :: vertloctab(nVertices+1)
        integer(SCOTCH_NUMSIZE), intent(in) :: nLocEdgesGraph
        integer(SCOTCH_NUMSIZE), intent(in) :: edgelocsiz
        integer(SCOTCH_NUMSIZE), intent(in) :: adjncy(nLocEdgesGraph)



        ! Return value
        integer :: ierr

        interface
            function scotchfdgraphbuild(dgraph_ptr, nVertices, vertloctab, &
                nLocEdgesGraph, edgelocsiz, adjncy) bind(C, name='scotchm_dgraphbuild') result(err)
                use iso_c_binding, only : c_ptr, c_int
                type(c_ptr), value :: dgraph_ptr
                integer(c_int), value :: nVertices
                integer(c_int) :: vertloctab(nVertices+1)
                integer(c_int), value :: nLocEdgesGraph
                integer(c_int), value :: edgelocsiz
                integer(c_int) :: adjncy(nLocEdgesGraph)
                integer(c_int) :: err
            end function scotchfdgraphbuild
        end interface


        ierr = 0

        ierr = scotchfdgraphbuild(c_loc(dgraph), nVertices, vertloctab,  &   
                                  nLocEdgesGraph, edgelocsiz, adjncy)

        if (ierr /= 0) then
            call mpas_log_write('Error building distributed Scotch graph', MPAS_LOG_CRIT)
        else 
            call mpas_log_write('Successfully built distributed Scotch graph')    
        end if


    end function scotch_dgraphbuild

    !-----------------------------------------------------------------------
    !  function scotch_dgraphcheck
    !
    !> \brief Perform consistency check on a SCOTCH distributed graph
    !> \author Abishek Gopal
    !> \date   8 Dec 2025
    !> \details
    !>  Validates the internal structure of a SCOTCH_Dgraph for consistency.
    !>  This function wraps the C function scotchm_dgraphcheck.
    !>  Returns an error code (0 if successful)
    !> \arguments
    !>   dgraph - SCOTCH_Dgraph structure to be checked
    !
    !-----------------------------------------------------------------------
    function scotch_dgraphcheck(dgraph) result(ierr)        
        use mpas_log, only : mpas_log_write
        use mpas_derived_types, only : MPAS_LOG_CRIT
        use iso_c_binding, only : c_ptr, c_loc

        implicit none

        doubleprecision, target, intent(in) :: dgraph (SCOTCH_DGRAPHDIM)

        ! Return value
        integer :: ierr

        interface
            function scotchfdgraphcheck(dgraph_ptr) bind(C, name='scotchm_dgraphcheck') result(err)
                use iso_c_binding, only : c_int, c_ptr
                type(c_ptr), value :: dgraph_ptr
                integer(c_int) :: err
            end function scotchfdgraphcheck
        end interface

        ierr = scotchfdgraphcheck(c_loc(dgraph))

        if (ierr /= 0) then
            call mpas_log_write('Error during distributed Scotch graph check', MPAS_LOG_CRIT)
        else 
            call mpas_log_write('Successfully checked distributed Scotch graph')    
        end if


    end function scotch_dgraphcheck

    !-----------------------------------------------------------------------
    !  subroutine scotch_dgraphexit
    !
    !> \brief Finalize/cleanup a SCOTCH distributed graph object
    !> \author Abishek Gopal
    !> \date   8 Dec 2025
    !> \details
    !>  Deallocates internal structures associated with a SCOTCH_Dgraph.
    !>  This subroutine wraps the C function scotchm_dgraphexit.
    !> \arguments
    !>   dgraph - SCOTCH_Dgraph structure to be finalized
    !
    !-----------------------------------------------------------------------
    subroutine scotch_dgraphexit(dgraph)        
        use mpas_log, only : mpas_log_write
        use iso_c_binding, only : c_ptr, c_loc

        implicit none

        doubleprecision, target, intent(in) :: dgraph (SCOTCH_DGRAPHDIM)

        interface
            subroutine scotchfdgraphexit(dgraph_ptr) bind(C, name='scotchm_dgraphexit')
                use iso_c_binding, only : c_int, c_ptr
                type(c_ptr), value :: dgraph_ptr
            end subroutine scotchfdgraphexit
        end interface

        call scotchfdgraphexit(c_loc(dgraph))

    end subroutine scotch_dgraphexit

    !-----------------------------------------------------------------------
    !  function scotch_stratinit
    !
    !> \brief Initialize a SCOTCH strategy object
    !> \author Abishek Gopal
    !> \date   8 Dec 2025
    !> \details
    !>  Initializes a SCOTCH_Strat structure and builds a default strategy
    !>  for distributed graph mapping. This function wraps the C function
    !>  scotchm_stratinit. Returns an error code (0 if successful)
    !> \arguments
    !>   stradat - SCOTCH_Strat structure to be initialized
    !
    !-----------------------------------------------------------------------
    function scotch_stratinit(stradat) result(ierr)        
        use mpas_log, only : mpas_log_write
        use mpas_derived_types, only : MPAS_LOG_CRIT
        use iso_c_binding, only : c_ptr, c_loc

        implicit none

        doubleprecision, target, intent(in) :: stradat (scotch_stratdim)
        
        ! Return value
        integer :: ierr

        interface
            function scotchfstratinit(strat_ptr) bind(C, name='scotchm_stratinit') result(err)
                use iso_c_binding, only : c_int, c_ptr
                type(c_ptr), value :: strat_ptr
                integer(c_int) :: err
            end function scotchfstratinit
        end interface

        ierr = scotchfstratinit(c_loc(stradat))

        if (ierr /= 0) then
            call mpas_log_write('Error during Scotch strategy initialization', MPAS_LOG_CRIT)
        else 
            call mpas_log_write('Successfully initialized Scotch strategy')
        end if

    end function scotch_stratinit

    !-----------------------------------------------------------------------
    !  subroutine scotch_stratexit
    !
    !> \brief Finalize/cleanup a SCOTCH strategy object
    !> \author Abishek Gopal
    !> \date   8 Dec 2025
    !> \details
    !>  Deallocates internal structures associated with a SCOTCH_Strat.
    !>  This subroutine wraps the C function scotchm_stratexit.
    !> \arguments
    !>   stradat - SCOTCH_Strat structure to be finalized
    !
    !-----------------------------------------------------------------------
    subroutine scotch_stratexit(stradat)        
        use mpas_log, only : mpas_log_write
        use iso_c_binding, only : c_ptr, c_loc

        implicit none

        doubleprecision, target, intent(in) :: stradat (scotch_stratdim)
        
        interface
            subroutine scotchfstratexit(strat_ptr) bind(C, name='scotchm_stratexit')
                use iso_c_binding, only : c_ptr
                type(c_ptr), value :: strat_ptr
            end subroutine scotchfstratexit
        end interface

        call scotchfstratexit(c_loc(stradat))

    end subroutine scotch_stratexit

    !-----------------------------------------------------------------------
    !  function scotch_dgraphpart
    !
    !> \brief Partition a SCOTCH distributed graph
    !> \author Abishek Gopal
    !> \date   8 Dec 2025
    !> \details
    !>  Partitions the distributed graph into num_part parts using the
    !>  provided SCOTCH strategy object. This function wraps the C function
    !>  scotchm_dgraphpart. Returns an error code (0 if successful)
    !> \arguments
    !>   dgraph  - SCOTCH_Dgraph structure to be partitioned
    !>   num_part - Number of partitions
    !>   stradat - SCOTCH_Strat structure containing partitioning strategy
    !>   parttab - Output array of size equal to number of local vertices,
    !
    !-----------------------------------------------------------------------
    function scotch_dgraphpart(dgraph, num_part, stradat, parttab) result(ierr)        
        use mpas_log, only : mpas_log_write
        use mpas_derived_types, only : MPAS_LOG_CRIT
        use iso_c_binding, only : c_ptr, c_loc

        implicit none

        doubleprecision, target, intent(in) :: dgraph (SCOTCH_DGRAPHDIM)
        integer(SCOTCH_NUMSIZE), intent(in) :: num_part
        doubleprecision, target, intent(in) :: stradat (scotch_stratdim)
        integer(SCOTCH_NUMSIZE), intent(out) :: parttab(*)
        
        ! Return value
        integer :: ierr

        interface
            function scotchfdgraphpart(dgraph_ptr, num_part_loc, strat_ptr, parttab_loc ) bind(C, name='scotchm_dgraphpart') result(err)
                use iso_c_binding, only : c_int, c_ptr
                type(c_ptr), value :: dgraph_ptr
                integer(c_int), value :: num_part_loc
                type(c_ptr), value :: strat_ptr
                integer(c_int) :: parttab_loc(*)
                integer(c_int) :: err
            end function scotchfdgraphpart
        end interface

        ierr = scotchfdgraphpart(c_loc(dgraph), num_part, c_loc(stradat), parttab)

        if (ierr /= 0) then
            call mpas_log_write('Error during Scotch graph partition', MPAS_LOG_CRIT)
        else 
            call mpas_log_write('Successfully partitioned distributed Scotch graph')
        end if

    end function scotch_dgraphpart

    !-----------------------------------------------------------------------
    !  function scotch_dgraphredist
    !
    !> \brief Redistribute a SCOTCH distributed graph according to partitions
    !> \author Abishek Gopal
    !> \date   8 Dec 2025
    !> \details
    !>  Redistributes the distributed graph structure based on a partition
    !>  table. This function wraps the C function scotchm_dgraphredist.
    !>  Returns an error code (0 if successful)
    !> \arguments
    !>   dgraph  - SCOTCH_Dgraph structure to be redistributed
    !>   parttab - Input array of size equal to number of local vertices,
    !>             containing partition assignments
    !>   dgraph_out - SCOTCH_Dgraph structure to hold redistributed graph
    !>   num_local_vertices - Number of local vertices in the redistributed graph
    !
    !-----------------------------------------------------------------------
    function scotch_dgraphredist(dgraph, parttab, dgraph_out, num_local_vertices) result(ierr)        
        use mpas_log, only : mpas_log_write
        use mpas_derived_types, only : MPAS_LOG_CRIT
        use iso_c_binding, only : c_ptr, c_loc

        implicit none

        doubleprecision, target, intent(in) :: dgraph (SCOTCH_DGRAPHDIM)
        integer(SCOTCH_NUMSIZE), intent(in) :: parttab(*)
        doubleprecision, target, intent(inout) :: dgraph_out (SCOTCH_DGRAPHDIM)
        integer(SCOTCH_NUMSIZE) :: num_local_vertices
           
        ! Return value
        integer :: ierr

        interface
            function scotchfdgraphredist(dgraph_ptr, parttab_loc, dgraph_out_ptr, vertlocnbr ) bind(C, name='scotchm_dgraphredist') result(err)
                use iso_c_binding, only : c_int, c_ptr
                type(c_ptr), value :: dgraph_ptr
                integer(c_int) :: parttab_loc(*)
                type(c_ptr), value :: dgraph_out_ptr
                integer(c_int) :: vertlocnbr
                integer(c_int) :: err
            end function scotchfdgraphredist
        end interface

        ierr = scotchfdgraphredist(c_loc(dgraph), parttab, c_loc(dgraph_out), num_local_vertices)

        if (ierr /= 0) then
            call mpas_log_write('Error during Scotch graph redistribution', MPAS_LOG_CRIT)
        else 
            call mpas_log_write('Successfully redistributed Scotch graph')
        end if


    end function scotch_dgraphredist

    !-----------------------------------------------------------------------
    !  function scotch_dgraphdata
    !
    !> \brief Extract vertex labels from a SCOTCH distributed graph
    !> \author Abishek Gopal
    !> \date   8 Dec 2025
    !> \details
    !>  Extracts vertex labels or stored IDs for local vertices into the
    !>  output array. This function wraps the C function scotchm_dgraphdata.
    !> \arguments
    !>   dgraph  - SCOTCH_Dgraph structure to extract from
    !>   local_cell_list - Output array to hold vertex labels for local vertices
    !
    !-----------------------------------------------------------------------
     subroutine scotch_dgraphdata(dgraph, local_cell_list)        
        use mpas_log, only : mpas_log_write
        use iso_c_binding, only : c_ptr, c_loc

        implicit none

        doubleprecision, target, intent(in) :: dgraph (SCOTCH_DGRAPHDIM)
        integer(SCOTCH_NUMSIZE), intent(out) :: local_cell_list(*)

        interface
            subroutine scotchfdgraphdata(dgraph_ptr, cell_list) bind(C, name='scotchm_dgraphdata')
                use iso_c_binding, only : c_int, c_ptr
                type(c_ptr), value :: dgraph_ptr
                integer(c_int) :: cell_list(*)
            end subroutine scotchfdgraphdata
        end interface

        call scotchfdgraphdata(c_loc(dgraph), local_cell_list)

    end subroutine scotch_dgraphdata


end module mpas_ptscotch_interface
#endif