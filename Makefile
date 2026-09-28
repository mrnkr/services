.PHONY: update-immich update-yattee update-pihole

UNIT_immich := immich
UNIT_yattee := yattee
UNIT_pihole := pihole

update-immich:
	cd immich && docker compose pull
	sudo systemctl restart $(or $(UNIT),$(UNIT_immich)).service

update-yattee:
	cd yattee && docker compose pull
	sudo systemctl restart $(or $(UNIT),$(UNIT_yattee)).service

update-pihole:
	cd pihole && docker compose pull
	sudo systemctl restart $(or $(UNIT),$(UNIT_pihole)).service
