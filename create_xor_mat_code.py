import numpy as np

def gf2_matmul(A, B):
    return (np.matmul(A, B) % 2).astype(np.int8)

def gf2_matrix_pow(A, p):
    size = A.shape[0]
    result = np.eye(size, dtype=np.int8)
    base = A.copy()
    while p > 0:
        if p % 2 == 1:
            result = gf2_matmul(result, base)
        base = gf2_matmul(base, base)
        p //= 2
    return result

size = 31
T = np.zeros((size, size), dtype=np.int8)

for i in range(size - 1):
    T[i, i + 1] = 1

T[30, 0] = 1
T[30, 3] = 1

M = gf2_matrix_pow(T, 1600)

# =================================================================
# CHỈ IN PHẦN ASSIGN RA TERMINAL
# =================================================================
for i in range(size):
    active_indices = [j for j in range(size) if M[i, j] == 1]
    
    if not active_indices:
        xor_expression = "1'b0"
    else:
        xor_expression = " ^ ".join([f"i_lfsr_state[{j}]" for j in active_indices])
    
    print(f"assign o_lfsr_state[{i:<2}] = {xor_expression};")