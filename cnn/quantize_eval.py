"""Step 2: load the FP32 model from train_mnist.py, round its weights to
lower-precision formats, and compare accuracy and model size.

Run:  python quantize_eval.py      (after train_mnist.py has produced mnist_cnn.pt)

Method: "fake quantization". Weights are rounded to the target format and
converted back to FP32 for the math, so this shows the accuracy cost of the
reduced precision. Activations stay in FP32.
"""
import torch
from torchvision import datasets, transforms

from train_mnist import Net, device


def fp_quant(t, dtype):
    """Round to a floating-point format (FP16 / FP8) and back to FP32."""
    return t.to(dtype).to(torch.float32)


def int_quant(t, bits):
    """Symmetric per-tensor integer quantization with `bits` bits."""
    qmax = 2 ** (bits - 1) - 1
    scale = t.abs().max() / qmax
    return torch.clamp(torch.round(t / scale), -qmax, qmax) * scale


def load_model(quant_fn=None):
    model = Net()
    model.load_state_dict(torch.load("mnist_cnn.pt", map_location="cpu"))
    if quant_fn is not None:
        with torch.no_grad():
            for p in model.parameters():
                p.copy_(quant_fn(p))
    return model.to(device).eval()


tf = transforms.Compose([
    transforms.ToTensor(),
    transforms.Normalize((0.1307,), (0.3081,)),
])
test_ds = datasets.MNIST("data", train=False, download=True, transform=tf)
test_dl = torch.utils.data.DataLoader(test_ds, batch_size=1000)


def accuracy(model):
    correct = 0
    with torch.no_grad():
        for x, y in test_dl:
            x, y = x.to(device), y.to(device)
            correct += (model(x).argmax(1) == y).sum().item()
    return 100 * correct / len(test_ds)


n_params = sum(p.numel() for p in Net().parameters())

formats = [
    ("FP32 (baseline)", None, 32),
    ("FP16", lambda t: fp_quant(t, torch.float16), 16),
    ("FP8 E4M3", lambda t: fp_quant(t, torch.float8_e4m3fn), 8),
    ("FP8 E5M2", lambda t: fp_quant(t, torch.float8_e5m2), 8),
    ("INT8", lambda t: int_quant(t, 8), 8),
    ("INT4", lambda t: int_quant(t, 4), 4),
]

print(f"{'Format':<18}{'Accuracy %':>12}{'Size (KB)':>12}")
for name, fn, bits in formats:
    acc = accuracy(load_model(fn))
    size_kb = n_params * bits / 8 / 1024
    print(f"{name:<18}{acc:>12.2f}{size_kb:>12.1f}")

# Accuracy vs integer bit-width sweep (this is where you look for the "knee")
sweep_bits = list(range(2, 9))
sweep_acc = []
for b in sweep_bits:
    sweep_acc.append(accuracy(load_model(lambda t, b=b: int_quant(t, b))))
print("\nINT bit-width sweep:")
for b, a in zip(sweep_bits, sweep_acc):
    print(f"  INT{b}: {a:.2f}%")

try:
    import matplotlib.pyplot as plt

    plt.plot(sweep_bits, sweep_acc, marker="o")
    plt.xlabel("Weight bit-width (INT)")
    plt.ylabel("Test accuracy (%)")
    plt.title("MNIST accuracy vs weight precision")
    plt.grid(True)
    plt.savefig("accuracy_vs_bits.png", dpi=150, bbox_inches="tight")
    print("saved accuracy_vs_bits.png")
except ImportError:
    print("matplotlib not installed: run `pip install matplotlib` to get the plot")
