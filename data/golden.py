import os

def get_matrix(input_file: str):
    if not os.path.exists(input_file):
        print(f"Error: {input_file} not found.")
        return []
    
    with open(input_file, 'r') as f:
        lines = f.readlines()

    data_matrix = []
    for line in lines:
        numbers = line.strip().split()
        if not numbers: continue
        int_numbers = [int(num_str) for num_str in numbers]
        data_matrix.append(int_numbers)
    
    print(f"Loaded {input_file}: {len(data_matrix)} rows x {len(data_matrix[0])} cols")
    return data_matrix

def matrix_multiply_and_scale(A, B_T, scale: float):
    """
    1. A (m x k) * B_T (n x k) 的转置 -> (m x n)
    2. Result * scale
    3. Round to nearest integer & Clamp to int8 range [-128, 127]
    """
    m = len(A)
    k = len(A[0])
    n = len(B_T)
    
    result = [[0 for _ in range(n)] for _ in range(m)]
    
    for i in range(m):
        for j in range(n):
            # 1. 矩阵乘法累加 (通常使用更高的精度，如 int32)
            acc = 0
            for l in range(k):
                acc += A[i][l] * B_T[j][l]
            
            # 2. 缩放
            scaled_val = acc * scale
            
            # 3. 四舍五入并截断到 int8 范围
            # 使用 round() 进行最近舍入，并使用 min/max 限制范围
            final_val = int(round(scaled_val))
            final_val = max(-128, min(127, final_val))
            
            result[i][j] = final_val
            
    return result

def save_matrix(matrix, output_file):
    with open(output_file, 'w') as f:
        for row in matrix:
            # 将 int8 结果写入文件
            line = " ".join(map(str, row))
            f.write(line + "\n")
    print(f"Quantized result saved to {output_file}")

# --- 主程序 ---
SCALE_FACTOR = 0.0011538403  # 示例 fp32 scale 数

w_test = get_matrix("weight_dec.txt") # 64 x 256
a_test = get_matrix("input_dec.txt")  # 16 x 256

if w_test and a_test:
    print(f"Calculating A * W^T with scale {SCALE_FACTOR}...")
    
    # 执行带缩放和量化的运算
    res_int8 = matrix_multiply_and_scale(a_test, w_test, SCALE_FACTOR)
    
    print(f"Result matrix size: {len(res_int8)} row x {len(res_int8[0])} col")
    save_matrix(res_int8, "output_int8.txt")