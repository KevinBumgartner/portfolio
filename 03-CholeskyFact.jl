# All code contained in this repository is the original work of Kevin Bumgartner.  It is provided
# here only for demonstration purposes, and it is not provided with any explicit or implicit
# permission to use the code for any purpose other than demonstration that the code works.

# The following Julia code ultimately provides a function called CholeskyFact(),
# which takes in a symmetric, positive definite matrix, and returns the Cholesky
# Factorization of that matrix.  I wrote this code for a homework assignment in
# a course in Numerical Algorithms.  The algorithm is not my own creation, but
# the code presented here is my own implementation of the algorithm.  The logic
# behind this algorithm is a bit more than someone should try and explain in a
# brief comment, but it's available in the book Numerical Algorithms by Justin
# Solomon.

using LinearAlgebra

function ForwardSub(L,c)
	n = size(L)[1]
	l = zeros(1,n)
	for i in 1:n
		if i==1
			l[1,i] = c[1,i]/L[i,i]
		else
			sumofl = 0
			for j in 1:(i-1)
				sumofl += L[i,j]*l[1,j]
			end
			l[1,i] = (c[1,i]-sumofl)/L[i,i]
		end
	end
	return l
end

function IsSymmetric(C)
	C==C'
end

function IsPosDef(C)
	n = size(C)[1]
	dets = zeros(n)
	dets[1] = C[1,1] > 0
	for i in 2:n
		dets[i] = det(C[1:i,1:i]) > 0
	end
	sum(dets)==size(dets)[1]
end

function CholeskyFact(C)
	if size(C)[1]!=size(C)[2]
	    return "Error: Matrix isn't square."
	end
	if !(IsSymmetric(C) & IsPosDef(C))
		return "Error: Matrix not symmetric positive definite."
	end
	n = size(C)[1]
	L = zeros(n,n)
	for i in 1:n
		if i==1
			L[i,i] = sqrt(C[1,1])
		else
			L11 = L[1:(i-1),1:(i-1)]
			c = zeros(1,(i-1))
			c[1,1:(i-1)] = C[i,1:(i-1)]
			l = ForwardSub(L11,c)
			L[i,1:(i-1)] = l[1,1:(i-1)]
			L[i,i] = sqrt(C[i,i]-(l*l')[1,1])
		end
	end
	return L'
end

# All code contained in this repository is the original work of Kevin Bumgartner.  It is provided
# here only for demonstration purposes, and it is not provided with any explicit or implicit
# permission to use the code for any purpose other than demonstration that the code works.
