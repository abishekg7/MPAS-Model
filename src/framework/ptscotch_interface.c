/*
 * Copyright (c) 2023, The University Corporation for Atmospheric Research (UCAR).
 *
 * Unless noted otherwise source code is licensed under the BSD license.
 * Additional copyright and license information can be found in the LICENSE file
 * distributed with this code, or at http://mpas-dev.github.com/license.html
 */

#include <stddef.h>
#include <stdlib.h>
#include <sys/stat.h>
#include <unistd.h>
#include <string.h>
#include <stdio.h>
#include <mpi.h>
#include "ptscotch.h"



typedef struct Dgraph_ {
  unsigned int                flagval;              /*+ Graph properties                                          +*/
  SCOTCH_Num                      baseval;              /*+ Base index for edge/vertex arrays                         +*/
  SCOTCH_Num                      vertglbnbr;           /*+ Global number of vertices                                 +*/
  SCOTCH_Num                      vertglbmax;           /*+ Maximum number of local vertices over all processes       +*/
  SCOTCH_Num                      vertgstnbr;           /*+ Number of local + ghost vertices                          +*/
  SCOTCH_Num                      vertgstnnd;           /*+ vertgstnbr + baseval                                      +*/
  SCOTCH_Num                      vertlocnbr;           /*+ Local number of vertices                                  +*/
  SCOTCH_Num                      vertlocnnd;           /*+ Local number of vertices + baseval                        +*/
  SCOTCH_Num *                    vertloctax;           /*+ Local vertex beginning index array [based]                +*/
  SCOTCH_Num *                    vendloctax;           /*+ Local vertex end index array [based]                      +*/
  SCOTCH_Num *                    veloloctax;           /*+ Local vertex load array if present                        +*/
  SCOTCH_Num                      velolocsum;           /*+ Local sum of all vertex loads                             +*/
  SCOTCH_Num                      veloglbsum;           /*+ Global sum of all vertex loads                            +*/
  SCOTCH_Num *                    vnumloctax;           /*+ Arrays of global vertex numbers in original graph         +*/
  SCOTCH_Num *                    vlblloctax;           /*+ Arrays of vertex labels (when read from file)             +*/
  SCOTCH_Num                      edgeglbnbr;           /*+ Global number of arcs                                     +*/
  SCOTCH_Num                      edgeglbmax;           /*+ Maximum number of local edges over all processes          +*/
  SCOTCH_Num                      edgelocnbr;           /*+ Number of local edges                                     +*/
  SCOTCH_Num                      edgelocsiz;           /*+ Size of local edge array (= edgelocnbr when compact)      +*/
  SCOTCH_Num                      edgeglbsmx;           /*+ Maximum size of local edge arrays over all processes      +*/
  SCOTCH_Num *                    edgegsttax;           /*+ Edge array holding local indices of neighbors [based]     +*/
  SCOTCH_Num *                    edgeloctax;           /*+ Edge array holding global neighbor numbers [based]        +*/
  SCOTCH_Num *                    edloloctax;           /*+ Edge load array                                           +*/
  SCOTCH_Num                      degrglbmax;           /*+ Maximum degree over all processes                         +*/
  SCOTCH_Num                      pkeyglbval;           /*+ Communicator key value: folded communicators are distinct +*/
  MPI_Comm                        proccomm;             /*+ Graph communicator                                        +*/
  SCOTCH_Num                      procglbnbr;           /*+ Number of processes sharing graph data                    +*/
  SCOTCH_Num                      proclocnum;           /*+ Number of this process                                    +*/
  SCOTCH_Num *                    procvrttab;           /*+ Global array of vertex number ranges [+1,based]           +*/
  SCOTCH_Num *                    proccnttab;           /*+ Count array for local number of vertices                  +*/
  SCOTCH_Num *                    procdsptab;           /*+ Displacement array with respect to proccnttab [+1,based]  +*/
  SCOTCH_Num                      procngbnbr;           /*+ Number of neighboring processes                           +*/
  SCOTCH_Num                      procngbmax;           /*+ Maximum number of neighboring processes                   +*/
  SCOTCH_Num *                    procngbtab;           /*+ Array of neighbor process numbers [sorted]                +*/
  SCOTCH_Num *                    procrcvtab;           /*+ Number of vertices to receive in ghost vertex sub-arrays  +*/
  SCOTCH_Num                      procsndnbr;           /*+ Overall size of local send array                          +*/
  SCOTCH_Num *                    procsndtab;           /*+ Number of vertices to send in ghost vertex sub-arrays     +*/
  SCOTCH_Num *                    procsidtab;           /*+ Array of indices to build communication vectors (send)    +*/
  SCOTCH_Num                      procsidnbr;           /*+ Size of the send index array                              +*/
} Dgraph2;



int scotchm_dgraphinit(void * ptr, int localcomm)
{
	MPI_Comm comm;
	MPI_Comm comm2;

	int size, rank, err;

	comm = MPI_Comm_f2c((MPI_Fint)localcomm);

	SCOTCH_Dgraph *dgraph = (SCOTCH_Dgraph *) ptr;
   
   err = SCOTCH_dgraphInit(dgraph, comm);

	return err;

}

int scotchm_dgraphbuild(void * ptr,
					   SCOTCH_Num nVertices, 
                       SCOTCH_Num * vertloctab_1,     
                       SCOTCH_Num nLocEdgesGraph, 
                       SCOTCH_Num edgelocsiz_1, 
                       SCOTCH_Num *adjncy
)
{
	SCOTCH_Num baseval = 1; // Fortran-style 1-based indexing
	SCOTCH_Num vertlocnbr = nVertices;
	SCOTCH_Num * veloloctab = NULL; // vertex weights not used
	SCOTCH_Num * vlblloctab = NULL; // vertex labels not used
	SCOTCH_Num edgelocnbr = nLocEdgesGraph;
	SCOTCH_Num edgelocsiz = edgelocsiz_1;	
	SCOTCH_Num * edgegsttab = NULL; // Optional array holding the local and ghost indices
	SCOTCH_Num * edloloctab = NULL; // Optional array of integer loads for each local edge

	SCOTCH_Num * vertloctab = (SCOTCH_Num *) vertloctab_1;
	SCOTCH_Num * vendloctab = vertloctab_1 + 1;
	SCOTCH_Num * edgeloctab = (SCOTCH_Num *) adjncy;

	int i,err;
	
	SCOTCH_Dgraph *dgraph = (SCOTCH_Dgraph *) ptr;	

	err = SCOTCH_dgraphBuild (dgraph,
							  baseval,
                          	  vertlocnbr,
							  vertlocnbr,
							  vertloctab,
							  vendloctab,
							  veloloctab, 
							  vlblloctab,
                          	  edgelocnbr,
							  edgelocsiz,
							  edgeloctab,
							  edgegsttab,
							  edloloctab);

	return err;

}



int scotchm_dgraphcheck(void * ptr)
{
	return SCOTCH_dgraphCheck((SCOTCH_Dgraph *) ptr);
}

int scotchm_dgraphpart(void * ptr, SCOTCH_Num num_part, void * ptr_strat, SCOTCH_Num * parttab){

	SCOTCH_Dgraph *dgraph = (SCOTCH_Dgraph *) ptr;
	SCOTCH_Strat *strat = (SCOTCH_Strat *) ptr_strat;

	return SCOTCH_dgraphPart(dgraph, num_part, strat, parttab);
}


int scotchm_dgraphredist(void * ptr, SCOTCH_Num *partloctab, void * ptr_out, SCOTCH_Num *vertlocnbr){

	SCOTCH_Dgraph *dgraph_in = (SCOTCH_Dgraph *) ptr;
	SCOTCH_Dgraph *dgraph_out = (SCOTCH_Dgraph *) ptr_out;
	SCOTCH_Num * permgsttab = NULL; // Redistribution permutation array
	SCOTCH_Num vertlocdlt = 0; // Extra size of local vertex array 
	SCOTCH_Num edgelocdlt = 0; // Extra size of local edge array
	int err;

	err = SCOTCH_dgraphRedist (dgraph_in, partloctab, permgsttab, vertlocdlt, edgelocdlt, dgraph_out);

	Dgraph2 *dgraph = (Dgraph2 *) dgraph_out;

	*vertlocnbr = dgraph->vertlocnbr;

	return err;
}



int scotchm_dgraphout(void * ptr, SCOTCH_Num * cell_list){

	SCOTCH_Num * permgsttab = NULL; // Redistribution permutation array
	SCOTCH_Num vertlocdlt = 0; // Extra size of local vertex array 
	SCOTCH_Num edgelocdlt = 0; // Extra size of local edge array
	int err;

	Dgraph2 *dgraph = (Dgraph2 *) ptr;

	for (SCOTCH_Num i=0; i < dgraph->vertlocnbr; i++) {
		cell_list[i] = *(dgraph->vlblloctax + dgraph->baseval + i);
	}
	return err;
}


void scotchm_dgraphexit(void *ptr)
{
	return SCOTCH_dgraphExit((SCOTCH_Dgraph *) ptr);
}

int scotchm_stratinit(void * strat_ptr)
{
	SCOTCH_stratInit((SCOTCH_Strat *) strat_ptr);
	//SCOTCH_stratDgraphMapBuild ((SCOTCH_Strat *) strat_ptr, SCOTCH_STRATDEFAULT, 16, 16, 0.03);
	//SCOTCH_stratDgraphMapBuild ((SCOTCH_Strat *) strat_ptr, SCOTCH_STRATSCALABILITY, 1, 0, 0.05);
	

	return 0;
}

void scotchm_stratexit(void * strat_ptr)
{
	return SCOTCH_stratExit((SCOTCH_Strat *) strat_ptr);
}
