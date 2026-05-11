# Event Notification

EventBridge + Step Functions + Lambda を使ったECSデプロイ通知システム

## 構成

ECSタスク更新
↓
EventBridge（イベント検知）
↓
Step Functions（ワークフロー管理）
↓
Lambda（通知処理）
↓
Slack（通知）

## 使用技術

- **言語**: Python 3.11
- **インフラ**: AWS（Lambda / Step Functions / EventBridge）
- **IaC**: Terraform

## 通知内容

ECSタスクがRUNNINGになったときに以下の情報をSlackに通知：

- クラスター名
- サービス名
- ステータス
- タスク定義

## インフラの構築手順

### 1. インフラの構築

```bash
cd infra
terraform init
terraform apply
```

### 2. 動作確認（Lambdaを直接テスト）

```bash
aws lambda invoke \
  --function-name event-notification \
  --payload '{"detail":{"clusterArn":"arn:aws:ecs:ap-northeast-1:ACCOUNT_ID:cluster/CLUSTER_NAME","group":"service:SERVICE_NAME","lastStatus":"RUNNING","taskDefinitionArn":"arn:aws:ecs:ap-northeast-1:ACCOUNT_ID:task-definition/TASK_DEF:1"}}' \
  --cli-binary-format raw-in-base64-out \
  --region ap-northeast-1 \
  response.json && cat response.json
```

## 環境の削除手順

```bash
cd infra
terraform destroy
```

## ファイル構成

event-notification/
├── lambda/
│   └── index.py          → Slack通知のLambda関数
└── infra/
├── main.tf            → AWSリソースの定義
├── variables.tf       → 変数の定義
├── outputs.tf         → 出力値の定義
└── terraform.tfvars   → 変数の値（gitignore済み）

## 注意事項

- `terraform.tfvars`にはSlack Webhook URLが含まれるため`.gitignore`に追加済み
- Slack Webhook URLは外部に公開しないこと

## 環境の再構築手順

### 1. リポジトリをクローン

```bash
git clone https://github.com/achuya/event-notification.git
cd event-notification
```

### 2. terraform.tfvarsを作成

```bash
cat > infra/terraform.tfvars << 'EOF'
aws_region        = "ap-northeast-1"
slack_webhook_url = "あなたのSlack Webhook URL"
EOF
```

### 3. インフラを構築

```bash
cd infra
terraform init
terraform apply
```

### 4. 動作確認

```bash
aws lambda invoke \
  --function-name event-notification \
  --payload '{"detail":{"clusterArn":"arn:aws:ecs:ap-northeast-1:ACCOUNT_ID:cluster/CLUSTER_NAME","group":"service:SERVICE_NAME","lastStatus":"RUNNING","taskDefinitionArn":"arn:aws:ecs:ap-northeast-1:ACCOUNT_ID:task-definition/TASK_DEF:1"}}' \
  --cli-binary-format raw-in-base64-out \
  --region ap-northeast-1 \
  response.json && cat response.json
```

Slackに通知が届けば成功！

---

## 環境の削除手順

### 1. インフラを削除

```bash
cd infra
terraform destroy
```

> ✅ 課題1と違いNAT Gatewayがないので課金は最小限です。
> ただし使い終わったら必ずdestroyしましょう！
