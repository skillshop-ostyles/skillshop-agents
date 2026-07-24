import pandas as pd
import numpy as np
from sklearn.model_selection import train_test_split, GroupKFold
from sklearn.preprocessing import StandardScaler

# Load data
data = pd.read_csv('dataset.csv')

# LEAKAGE: Preprocessing BEFORE split
scaler = StandardScaler()
X_scaled = scaler.fit_transform(data[['feature1', 'feature2']])  # fit_transform on full data -- LEAKS test info!
X_train, X_test, y_train, y_test = train_test_split(X_scaled, data['target'], test_size=0.2, random_state=42)

# CLEAN: Split before preprocessing
X = data[['feature1', 'feature2']]
y = data['target']
X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)
scaler = StandardScaler()
X_train_scaled = scaler.fit_transform(X_train)  # fit_transform only on training -- clean
X_test_scaled = scaler.transform(X_test)

# GROUP LEAK: Same user in train and test
user_ids = data['user_id']
# Using train_test_split without group_id -- same user can appear in both sets
X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2)
# Should use GroupKFold with user_id to prevent group leakage
