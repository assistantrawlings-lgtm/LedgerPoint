# Deployment blocker

The automated deployment could not create Azure resources because the active Azure subscription is currently in a read-only disabled state.

Evidence:
- Command: az account show --output json
- Result: subscription id 58649058-4b49-4057-8fed-2d1ca996ed66 is enabled in the account profile, but write operations failed with ReadOnlyDisabledSubscription.
- Command: ./deploy.sh
- Result: Azure CLI returned ReadOnlyDisabledSubscription and the provisioning step stopped.

Next step:
- Re-enable the subscription or switch to an enabled subscription and rerun ./deploy.sh.
