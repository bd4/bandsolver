      subroutine test_band_batched(n,kl,ku,                                     &
     &                 max_err, max_res,batchCount )
! % ---------------------------------------------
! % simple test for bandfactor() and bandsolver()
! % ---------------------------------------------
      implicit none
      integer, intent(in) :: n, kl, ku, batchCount
      real(kind=wp) :: max_err, max_res

       integer, parameter :: idebug = 1
       complex(kind=wp), allocatable :: A(:,:,:)
       complex(kind=wp), allocatable :: Aorg(:,:,:)
       complex(kind=wp), allocatable :: x(:,:), xnew(:,:), b(:,:)
       integer, allocatable :: ipiv(:,:)

       integer :: ldA,inc
       integer :: ibatch, i, info
       logical :: isok

       real(kind=wp) :: err, res
       real(kind=wp) :: x_re(n), x_im(n)
       integer :: kl_array(batchCount)
       integer :: ku_array(batchCount)
       integer :: info_array(batchCount)

       real(kind=wp) :: huge = 1.0d9

       max_err = huge
       max_res = huge

      ldA = n
      allocate( ipiv(n,batchCount) )
      allocate( A(ldA, n, batchCount), Aorg(ldA,n,batchCount)  )
      call gen_banded_batched( n, kl, ku, A, lda, batchCount)

!$omp parallel do private(ibatch)
      do ibatch=1,batchCount
	 Aorg(:,:,ibatch) = A(:,:,ibatch)
      enddo

      allocate( b(n,batchCount), x(n,batchCount), xnew(n,batchCount) )

!$omp parallel do private(ibatch,x_re,x_im,i)
      do ibatch=1,batchCount
	 call random_number(x_re(1:n))
	 call random_number(x_im(1:n))
	 x_re(1:n) = 2*x_re(1:n) - 1
	 x_im(1:n) = 2*x_im(1:n) - 1
	 do i=1,n
	   x(i,ibatch) = cmplx( x_re(i), x_im(i), kind=wp)
	 enddo
       enddo

! % -------------------------
! % generate solution and rhs
! % -------------------------
!$omp  parallel do private(ibatch)
       do ibatch=1,batchCount
	  b(1:n,ibatch) = matmul( Aorg(1:n,1:n,ibatch), x(1:n,ibatch))
       enddo
! 
! % ---------------------
! % perform factorization
! %
! % note new bandwidth may be larger due to pivoting
! % kl2 ~ 2*(kl+ku), ku2 ~ 2*ku
! % ---------------------

       call bandfactor_batched(n,A,lda,ipiv,kl_array,ku_array,                        &
     &              info_array, batchCount)
       isok = all( info_array(1:batchCount).eq.0 )
       if (.not.isok) then
	  do ibatch=1,batchCount
            info = info_array(ibatch)
	    if (info.ne.0) then
	      print*,'ibatch,info ', ibatch,info
	    endif
	  enddo
	  return
	endif


       inc = 1
       call bandsolve_batched(n, kl_array,ku_array,A,ldA,                             &
     &                  ipiv,b,inc,batchCount)

       do ibatch=1,batchCount
	  xnew(1:n,ibatch) = b(1:n,ibatch)
       enddo

       max_err = 0
       max_res = 0
       do ibatch=1,batchCount
	  do i=1,n
            err = abs( xnew(i,ibatch) - x(i,ibatch) )
	    max_err = max( max_err, err )
	  enddo
       enddo

       do ibatch=1,batchCount
	b(1:n,ibatch) = matmul( Aorg(1:n,1:n,ibatch), xnew(1:n,ibatch) )
	b(1:n,ibatch) = b(1:n,ibatch) - matmul(Aorg(1:n,1:n,ibatch),x(1:n,ibatch))
       enddo

       do ibatch=1,batchCount
       do i=1,n
	  res = abs( b(i,ibatch) )
	  max_res = max( max_res, res )
       enddo
       enddo

!      --------
!      clean up
!      --------
       deallocate( b, x, xnew )
       deallocate( A, Aorg )
       deallocate( ipiv )

       return
       end subroutine test_band_batched
