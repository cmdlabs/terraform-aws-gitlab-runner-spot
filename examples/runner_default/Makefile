.PHONY: plan
plan:
	terraform plan -out tf.plan ; \
		terraform show -json tf.plan | jq . > plan.json ; \
		rm -f tf.plan
