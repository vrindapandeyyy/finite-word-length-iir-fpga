"""Step 1: download MNIST, train a small CNN in FP32, save the weights.

Run:  python train_mnist.py
Output: mnist_cnn.pt (weights) and the FP32 baseline test accuracy.
"""
import torch
import torch.nn as nn
import torch.nn.functional as F
from torchvision import datasets, transforms

device = "cuda" if torch.cuda.is_available() else "cpu"


class Net(nn.Module):
    def __init__(self):
        super().__init__()
        self.conv1 = nn.Conv2d(1, 8, 3)    # 28x28 -> 26x26
        self.conv2 = nn.Conv2d(8, 16, 3)   # 26x26 -> 24x24, pooled to 12x12
        self.fc = nn.Linear(16 * 12 * 12, 10)

    def forward(self, x):
        x = F.relu(self.conv1(x))
        x = F.max_pool2d(F.relu(self.conv2(x)), 2)
        return self.fc(x.flatten(1))


def main():
    tf = transforms.Compose([
        transforms.ToTensor(),
        transforms.Normalize((0.1307,), (0.3081,)),
    ])
    # download=True fetches MNIST into ./data the first time (about 60 MB of files)
    train_ds = datasets.MNIST("data", train=True, download=True, transform=tf)
    test_ds = datasets.MNIST("data", train=False, download=True, transform=tf)
    train_dl = torch.utils.data.DataLoader(train_ds, batch_size=128, shuffle=True)
    test_dl = torch.utils.data.DataLoader(test_ds, batch_size=1000)

    model = Net().to(device)
    opt = torch.optim.Adam(model.parameters(), lr=1e-3)

    for epoch in range(2):
        model.train()
        for x, y in train_dl:
            x, y = x.to(device), y.to(device)
            opt.zero_grad()
            F.cross_entropy(model(x), y).backward()
            opt.step()
        print(f"epoch {epoch + 1} done")

    model.eval()
    correct = 0
    with torch.no_grad():
        for x, y in test_dl:
            x, y = x.to(device), y.to(device)
            correct += (model(x).argmax(1) == y).sum().item()
    print(f"FP32 test accuracy: {100 * correct / len(test_ds):.2f}%")

    torch.save(model.state_dict(), "mnist_cnn.pt")
    print("saved mnist_cnn.pt")


if __name__ == "__main__":
    main()
