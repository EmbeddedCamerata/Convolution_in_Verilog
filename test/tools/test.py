import numpy as np
import argparse
from pathlib import Path
from typing import Union


def numpy_conv(fm, kernel):
    h_fm, w_fm = fm.shape
    h_k, w_k = kernel.shape

    h_new, w_new = h_fm - h_k + 1, w_fm - w_k + 1
    result = np.zeros((h_new, w_new), np.uint16)

    for row in range(h_new):
        for col in range(w_new):
            cur_input = fm[row : row + h_k, col : col + w_k]
            cur_output = cur_input * kernel
            conv_sum = np.sum(cur_output)
            result[row, col] = conv_sum

    return result


def gen_data(size: int = 5, channel: int = 3):
    data = np.zeros([channel, size, size])

    for i in range(channel):
        m = np.random.randint(0, 256, (size, size), np.uint8)
        data[i] = m

    return data


def get_ref_results(fmap, kernel):
    _, h_in, _ = fmap.shape
    cout, h_k, _ = kernel.shape

    h_out = h_in - h_k + 1

    result = np.zeros((cout, h_out, h_out))
    for i in range(cout):
        result[i] = numpy_conv(fmap[i], kernel[i])

    return result


def save_in_mem(filename: Union[str, Path], data) -> None:
    with open(filename, "w") as f:
        f.write("@00")
        for d in data.flatten():
            d_x = hex(d.astype(int)).split("0x")[1]
            f.write("\n" + d_x)


def check(result_filename: Union[str, Path], ref_filename: Union[str, Path]) -> None:
    """
    Read the result.mem from testbench, and compare with the reference result

    Params:
    - result_filename: The file of actual results output from the testbench.
    - ref_filename: The file of reference results.
    """
    if not Path(result_filename).exists() or not Path(ref_filename).exists():
        raise FileNotFoundError("Results file not found!")

    result = []
    result_ref = []

    with open(result_filename, "r") as f:
        for res in f.readlines():
            res = res.rstrip().strip("\n")

            if not res.startswith("//"):
                d_res = int(res, 16)
                result.append(d_res)

    with open(ref_filename, "r") as fr:
        for ref in fr.readlines():
            ref = ref.rstrip().strip("\n")

            if not ref.startswith("@"):
                d_ref = int(ref, 16)
                result_ref.append(d_ref)

    print(result == result_ref)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    parser.add_argument(
        "-i", "--input", help="Input feature map size", type=int, default=48
    )
    parser.add_argument("-c", "--channel", help="Kernel channel", type=int, default=3)
    parser.add_argument("-k", "--kernel", help="Kernel size", type=int, default=3)

    opt = parser.parse_args()
    
    save_in_dir = Path("./data")
    
    if not save_in_dir.exists():
        save_in_dir.mkdir(exist_ok=True, parents=True)

    if opt.check:
        check("./data/results.mem", "./data/results_ref.mem")
    else:
        input_size = opt.input
        channel = opt.channel
        kernel_size = opt.kernel
        output_size = input_size - kernel_size + 1

        a = gen_data(input_size, channel)
        w = gen_data(kernel_size, channel)
        r = get_ref_results(a, w)

        # Save test data into files
        save_in_mem("./data/fmap.mem", a)
        save_in_mem("./data/weights.mem", w)
        save_in_mem("./data/results_ref.mem", r)
