import numpy as np
from torch.utils.data import DataLoader
from sklearn.model_selection import train_test_split

X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2)
loader = DataLoader(dataset, batch_size=32, shuffle=True)
