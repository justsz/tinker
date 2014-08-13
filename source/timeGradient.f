c
c
c     ###################################################
c     ##  COPYRIGHT (C)  1990  by  Jay William Ponder  ##
c     ##              All Rights Reserved              ##
c     ###################################################
c
c     ###############################################################
c     ##                                                           ##
c     ##  program timer  --  timer for Cartesian energy functions  ##
c     ##                                                           ##
c     ###############################################################
c
c
c     "timer" measures the CPU time required for file reading and
c     parameter assignment, potential energy computation, energy
c     and gradient computation, and Hessian matrix evaluation
c
c
      program timer
      use sizes
      use atoms
      use hescut
      use inform
      use iounit
      use limits
c      use omp_lib
      implicit none
      integer i,ncalls,next
      integer, allocatable :: hindex(:)
      integer, allocatable :: hinit(:,:)
      integer, allocatable :: hstop(:,:)
      real*8 value,energy
      real*8 wall,cpu
      real*8, allocatable :: h(:)
      real*8, allocatable :: hdiag(:,:)
      real*8, allocatable :: derivs(:,:)
      logical exist,query
      logical dohessian
      character*1 answer
      character*120 record
      character*120 string
      integer omp_get_num_threads 

!$pomp inst init

c
c
c     read in the molecular system to be timed
c
      call initial
      call getxyz
c
c     get the number of calculation cycles to perform
c
      ncalls = 0
      query = .true.
      call nextarg (string,exist)
      if (exist) then
         read (string,*,err=10,end=10)  ncalls
         query = .false.
      end if
   10 continue
      if (query) then
         write (iout,20)
   20    format (/,' Enter Desired Number of Repetitions [1] :  ',$)
         read (input,30)  ncalls
   30    format (i10)
      end if
      if (ncalls .eq. 0)  ncalls = 1
c
c     decide whether to include timing of Hessian evaluations
c
      dohessian = .true.
      call nextarg (answer,exist)
      if (.not. exist) then
         write (iout,40)
   40    format (/,' Include Timing for Hessian Evaluations [Y] :  ',$)
         read (input,50)  record
   50    format (a120)
         next = 1
         call gettext (record,answer,next)
      end if
      call upcase (answer)
      if (answer .eq. 'N')  dohessian = .false.
c
c     perform dynamic allocation of some local arrays
c
      if (dohessian) then
         allocate (hindex((3*n*(3*n-1))/2))
         allocate (hinit(3,n))
         allocate (hstop(3,n))
         allocate (h((3*n*(3*n-1))/2))
         allocate (hdiag(3,n))
      end if
      allocate (derivs(3,n))
c
c     get the timing for setup of the calculation
c
      call settime
      call mechanic
      
!$OMP PARALLEL
!$OMP MASTER
      print *, "Number of threads:", omp_get_num_threads()
!$OMP END MASTER
!$OMP END PARALLEL

      if (use_list)  call nblist
      call gettime (wall,cpu)
      write (iout,60)  ncalls
   60 format (/,' Total Wall Clock and CPU Time in Seconds for',
     &           i6,' Evaluations :')
      write (iout,70)  wall,cpu
   70 format (/,' Computation Set-up :',f15.3,' Sec (Wall)',
     &           f15.3,' Sec (CPU)')
c
c     set a large Hessian cutoff and turn off extra printing
c
      hesscut = 1.0d0
      verbose = .false.
c
c     run the energy and gradient timing experiment
c
      call settime
      do i = 1, ncalls
         call gradient (value,derivs)
      end do
      call gettime (wall,cpu)
      write (iout,90)  wall,cpu
   90 format (/,' Energy & Gradient : ',f15.3,' Sec (Wall)',
     &           f15.3,' Sec (CPU)')
      
      print *, "Gradient value:", sum(abs(derivs))
c
c     repeat the energy and gradient timing experiment
c
      call settime
      do i = 1, ncalls
         call gradient (value,derivs)
      end do
      call gettime (wall,cpu)
      write (iout,120)  wall,cpu
  120 format (/,' Energy & Gradient : ',f15.3,' Sec (Wall)',
     &           f15.3,' Sec (CPU)')

c
c     perform deallocation of some local arrays
c
      if (dohessian) then
         deallocate (hindex)
         deallocate (hinit)
         deallocate (hstop)
         deallocate (h)
         deallocate (hdiag)
      end if
      deallocate (derivs)
c
c     perform any final tasks before program exit
c
      call final
      end