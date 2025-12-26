with open("weight_test_2_dec.txt", "w") as f:
    for _ in range(4):
        for i in range(1, 17):
            # 创建包含16个数字的列表，并用空格连接
            for j in range(16):
                line = " ".join([str(i-j)] * 16)
                f.write(line + " ")
            f.write("\n")
with open("input_test_2_dec.txt", "w") as f:
    for i in range(1, 17):
        # 创建包含16个数字的列表，并用空格连接
        for j in range(16):
            line = " ".join([str(i+j)] * 16)
            f.write(line + " ")
        f.write("\n")