# BAD: no random seed - non-deterministic
import numpy as np
from torch.utils.data import DataLoader
from sklearn.model_selection import train_test_split

X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2)
loader = DataLoader(dataset, batch_size=32, shuffle=True)

# GOOD: seeded properly
import torch
import random

random.seed(42)
np.random.seed(42)
torch.manual_seed(42)
torch.backends.cudnn.deterministic = True
torch.backends.cudnn.benchmark = False

X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)
loader = DataLoader(dataset, batch_size=32, shuffle=True, generator=torch.Generator().manual_seed(42))
