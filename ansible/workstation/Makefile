install:
	# sudo apt-add-repository ppa:ansible/ansible
	# sudo apt install -y ansible | true
	ansible-galaxy collection install community.general

run:
	@sudo -v
	ansible-playbook -i inventory ansible.yml

# One-time bootstrap on a fresh cloud VM (default user is usually "ubuntu"):
# creates a passwordless, NOPASSWD-sudo "alex" user with the same SSH
# authorized_keys as the ubuntu user, so Cursor's Remote-SSH can connect as
# alex from the laptop and `make run` can be run as that user afterwards.
#
#   make bootstrap-user HOST=1.2.3.4 [REMOTE_USER=ubuntu]
bootstrap-user:
	@test -n "$(HOST)" || (echo "Usage: make bootstrap-user HOST=<ip-or-hostname> [REMOTE_USER=ubuntu]" && exit 1)
	ssh $(or $(REMOTE_USER),ubuntu)@$(HOST) ' \
		set -e; \
		sudo id -u alex >/dev/null 2>&1 || sudo useradd -m -s /bin/bash alex; \
		sudo mkdir -p /home/alex/.ssh; \
		sudo cp ~/.ssh/authorized_keys /home/alex/.ssh/authorized_keys; \
		sudo chown -R alex:alex /home/alex/.ssh; \
		sudo chmod 700 /home/alex/.ssh; \
		sudo chmod 600 /home/alex/.ssh/authorized_keys; \
		sudo passwd -l alex; \
		echo "alex ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/alex >/dev/null; \
		sudo chmod 0440 /etc/sudoers.d/alex; \
		sudo visudo -cf /etc/sudoers.d/alex; \
		echo "alex is ready for Remote-SSH as alex@$(HOST)" \
	'
