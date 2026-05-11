import json
import urllib.request
import os


def lambda_handler(event, context):
    webhook_url = os.environ["SLACK_WEBHOOK_URL"]

    # Step Functionsから受け取ったイベント情報
    detail = event.get("detail", {})
    cluster = detail.get("clusterArn", "").split("/")[-1]
    service = detail.get("group", "").replace("service:", "")
    status = detail.get("lastStatus", "UNKNOWN")
    task_def = detail.get("taskDefinitionArn", "").split("/")[-1]

    message = {
        "text": f"🚀 *ECSデプロイ通知*",
        "attachments": [
            {
                "color": "#36a64f",
                "fields": [
                    {
                        "title": "クラスター",
                        "value": cluster,
                        "short": True
                    },
                    {
                        "title": "サービス",
                        "value": service,
                        "short": True
                    },
                    {
                        "title": "ステータス",
                        "value": status,
                        "short": True
                    },
                    {
                        "title": "タスク定義",
                        "value": task_def,
                        "short": True
                    }
                ]
            }
        ]
    }

    data = json.dumps(message).encode("utf-8")
    req = urllib.request.Request(
        webhook_url,
        data=data,
        headers={"Content-Type": "application/json"}
    )

    with urllib.request.urlopen(req) as response:
        return {
            "statusCode": response.status,
            "body": response.read().decode("utf-8")
        }