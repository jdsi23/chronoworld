import boto3
import os

dynamodb = boto3.resource('dynamodb')
table_name = os.environ.get('TABLE_NAME', 'ChronoWorldShowtimes')  # Set in Terraform
table = dynamodb.Table(table_name)

def lambda_handler(event, context):
    # Grab the search query
    query = event.get("eventName", "").lower()

    if not query:
        return {
            "statusCode": 400,
            "body": "Missing 'eventName' in request."
        }

    # Scan the table (later we can optimize with Query if needed)
    response = table.scan()
    all_items = response.get("Items", [])

    # Filter for partial matches (case-insensitive)
    matches = [item for item in all_items if query in item.get("eventName", "").lower()]

    if not matches:
        return {
            "statusCode": 404,
            "body": f"No events found for '{query}'."
        }

    return {
        "statusCode": 200,
        "body": matches
    }
