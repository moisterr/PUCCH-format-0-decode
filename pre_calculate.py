def get_3gpp_gold_sequence(c_init, length):
    Nc = 1600
    x1 = [0] * (Nc + length + 31)
    x2 = [0] * (Nc + length + 31)
    x1[0] = 1
    for i in range(31):
        x2[i] = (c_init >> i) & 1
    for n in range(Nc + length):
        x1[n+31] = x1[n+3] ^ x1[n]
        x2[n+31] = x2[n+3] ^ x2[n+2] ^ x2[n+1] ^ x2[n]
    c = [(x1[n+Nc] ^ x2[n+Nc]) for n in range(length)]
    return c

def bits_to_val(bit_list):
    return sum(b * (2**i) for i, b in enumerate(bit_list))

# =================================================================
# --- Cấu hình hệ thống ---
# =================================================================
PCI  = 120  
f_ss = PCI % 30  

# 1. Sinh chuỗi Gold cho Group Hopping (u) - Tính theo Slot
c_init_fgh = PCI // 30
fgh_seq = get_3gpp_gold_sequence(c_init_fgh, 20 * 8)

# 2. Sinh chuỗi Gold cho Sequence Hopping (n_cs) - Tính theo Symbol
c_init_ncs = PCI
ncs_seq = get_3gpp_gold_sequence(c_init_ncs, 20 * 14 * 8)

# Tiêu đề bảng hiển thị song song cả 2 trường hợp để tiện so sánh
print(f"{'Slot':<5} | {'Symb':<5} | {'f_gh(GH=1)':<10} | {'u(GH=1)':<8} | {'f_gh(GH=0)':<10} | {'u(GH=0)':<8} | {'n_cs(Hop)':<10}")
print("-" * 80)

for slot in range(20):
    # --- TRƯỜNG HỢP 1: groupHopping = 1 (Bật) ---
    fgh_bits = fgh_seq[slot * 8 : (slot + 1) * 8]
    f_gh_1   = bits_to_val(fgh_bits) % 30
    u_1      = (f_gh_1 + f_ss) % 30 

    # --- TRƯỜNG HỢP 2: groupHopping = 0 (Tắt) ---
    f_gh_0   = 0
    u_0      = (f_gh_0 + f_ss) % 30 

    for symb in range(14):
        # n_cs (hopping) thay đổi theo từng symbol, độc lập với cấu hình groupHopping
        idx_base = (slot * 14 + symb) * 8
        ncs_bits = ncs_seq[idx_base : idx_base + 8]
        n_cs     = bits_to_val(ncs_bits) % 12

        print(f"{slot:<5} | {symb:<5} | {f_gh_1:<10} | {u_1:<8} | {f_gh_0:<10} | {u_0:<8} | {n_cs:<10}")