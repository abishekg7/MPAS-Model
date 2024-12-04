.SUFFIXES: .F .o
.SECONDARY: $(%_ser.F)

# Generated source files
#GEN_SRC = m_ser_o.F

#OBJS = $(GEN_SRC:.F=.o) mpas_atm_time_integration.o \
#       mpas_atm_boundaries.o

GEN_SRC = m_ser_ser.F mpas_atm_time_integration_ser.F
#GEN_SRC = m_ser_ser.F

#OBJS = $(GEN_SRC:.F=.o) mpas_atm_time_integration.o mpas_atm_boundaries.o
OBJS = $(GEN_SRC:.F=.o) mpas_atm_boundaries.o
#OBJS = $(patsubst %.F, %.F.o, $(filter %_o.F, $(GEN_SRC))) mpas_atm_boundaries.o
#OBJS = $(patsubst %.F, %.F.o, $(filter %_o.F, $(GEN_SRC))) mpas_atm_time_integration.o mpas_atm_boundaries.o
$(info ************  OBJSSS ************)
$(info ************  ${OBJS} ************)

# Static library
SERLIB = libsimple_m_ser.a

all: $(OBJS) $(SERLIB)

mpas_atm_time_integration_ser.o: mpas_atm_boundaries.o mpas_atm_iau.o

mpas_atm_boundaries.o:


clean:
	$(RM) *.o *.mod *.f90
	@# Certain systems with intel compilers generate *.i files
	@# This removes them during the clean process
	$(RM) *.i

# Rule to generate m_ser_o.F90 from m_ser.F90
# m_ser_o.F: m_ser.F
# 	/glade/derecho/scratch/agopal/serialbox_2.6.2_2/install/python/pp_ser/pp_ser.py $< -o $@

%_ser.F: %.F
	/glade/derecho/scratch/agopal/serialbox_2.6.2_2/install/python/pp_ser/pp_ser.py $< -o $@	

# Rule to create the static library
# $(SERLIB): m_ser_o.o
# 	/usr/bin/ar qc $@ $^
# 	/usr/bin/ranlib $@

$(SERLIB): m_ser_ser.o
	/usr/bin/ar qc $@ $^
	/usr/bin/ranlib $@


.F.o:
	$(RM) $@ $*.mod
ifeq "$(GEN_F90)" "true"
	$(CPP) $(CPPFLAGS) $(PHYSICS) $(CPPINCLUDES) $< > $*.f90
	$(FC) $(FFLAGS) -c $*.f90 $(FCINCLUDES) -I.. -I../../framework -I../../operators -I../physics -I../physics/physics_wrf -I../physics/physics_mmm -I../../external/esmf_time_f90
	$(info ************  first ************)
else
	$(FC) $(CPPFLAGS) $(PHYSICS) $(FFLAGS) -c $*.F $(CPPINCLUDES) $(FCINCLUDES) -I.. -I../../framework -I../../operators -I../physics -I../physics/physics_wrf -I../physics/physics_mmm -I../../external/esmf_time_f90
	$(info ************  second ************)
endif

%_ser.o: %_ser.F
	$(FC) $(CPPFLAGS) $(PHYSICS) $(FFLAGS) -c $< $(CPPINCLUDES) $(FCINCLUDES) -I.. -I../../framework -I../../operators -I../physics -I../physics/physics_wrf -I../physics/physics_mmm -I../../external/esmf_time_f90
	$(info ************  third ************)