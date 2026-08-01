import pandas as pd
from sqlalchemy import create_engine
import xgboost as xgb
from sklearn.model_selection import train_test_split
from sklearn.metrics import classification_report, f1_score
import joblib
import os
from dotenv import load_dotenv
import optuna

load_dotenv()
engine = create_engine(os.getenv("DATABASE_URL"))

query = """
WITH time_bounds AS (
    SELECT MAX(order_purchase_timestamp) AS max_date, MAX(order_purchase_timestamp) - INTERVAL '6 months' AS cutoff_date FROM orders
),
historical_features AS (
    SELECT 
        c.customer_unique_id, 
        EXTRACT(DAY FROM (t.cutoff_date - MAX(o.order_purchase_timestamp))) AS recency, 
        COUNT(DISTINCT o.order_id) AS frequency, 
        SUM(oi.price + oi.freight_value) AS monetary,
        AVG(rv.review_score) AS avg_review_score,
        AVG(EXTRACT(EPOCH FROM (o.order_delivered_customer_date - o.order_estimated_delivery_date))/86400.0) AS delivery_delay_days,
        AVG(oi.freight_value / NULLIF((oi.price + oi.freight_value), 0)) AS freight_ratio
    FROM orders o 
    JOIN olist_customers_dataset c ON o.customer_id = c.customer_id 
    JOIN order_items oi ON o.order_id = oi.order_id 
    LEFT JOIN order_reviews rv ON o.order_id = rv.order_id
    CROSS JOIN time_bounds t 
    WHERE o.order_purchase_timestamp <= t.cutoff_date 
    GROUP BY c.customer_unique_id, t.cutoff_date
),
future_purchases AS (
    SELECT DISTINCT c.customer_unique_id FROM orders o JOIN olist_customers_dataset c ON o.customer_id = c.customer_id CROSS JOIN time_bounds t WHERE o.order_purchase_timestamp > t.cutoff_date
)
SELECT 
    h.customer_unique_id, 
    h.recency, 
    h.frequency, 
    h.monetary, 
    h.avg_review_score,
    h.delivery_delay_days,
    h.freight_ratio,
    CASE WHEN f.customer_unique_id IS NOT NULL THEN 0 ELSE 1 END AS is_churned 
FROM historical_features h 
LEFT JOIN future_purchases f ON h.customer_unique_id = f.customer_unique_id;
"""

df = pd.read_sql(query, engine)

df['avg_review_score'] = df['avg_review_score'].fillna(df['avg_review_score'].median())
df['delivery_delay_days'] = df['delivery_delay_days'].fillna(0)
df['freight_ratio'] = df['freight_ratio'].fillna(0)

X = df[['recency', 'frequency', 'monetary', 'avg_review_score', 'delivery_delay_days', 'freight_ratio']]
y = df['is_churned']

X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42, stratify=y)
X_train_opt, X_val_opt, y_train_opt, y_val_opt = train_test_split(X_train, y_train, test_size=0.2, random_state=42, stratify=y_train)

imbalance_ratio = float((y_train == 0).sum() / (y_train == 1).sum())

def objective(trial):
    params = {
        'eval_metric': 'logloss',
        'scale_pos_weight': imbalance_ratio,
        'max_depth': trial.suggest_int('max_depth', 3, 9),
        'learning_rate': trial.suggest_float('learning_rate', 1e-3, 0.1, log=True),
        'n_estimators': trial.suggest_int('n_estimators', 50, 300),
        'subsample': trial.suggest_float('subsample', 0.6, 1.0),
        'colsample_bytree': trial.suggest_float('colsample_bytree', 0.6, 1.0)
    }
    
    opt_model = xgb.XGBClassifier(**params)
    opt_model.fit(X_train_opt, y_train_opt)
    
    y_val_pred = opt_model.predict(X_val_opt)
    return f1_score(y_val_opt, y_val_pred, pos_label=0)

study = optuna.create_study(direction='maximize')
study.optimize(objective, n_trials=20)

best_params = study.best_params
best_params['eval_metric'] = 'logloss'
best_params['scale_pos_weight'] = imbalance_ratio

final_model = xgb.XGBClassifier(**best_params)
final_model.fit(X_train, y_train)

y_pred = final_model.predict(X_test)
print("\nBest Optuna Trial F1-Score:", study.best_trial.value)
print("Best Hyperparameters:", study.best_params)
print("\nFinal Classification Report:\n", classification_report(y_test, y_pred))

joblib.dump(final_model, 'churn_model.joblib')