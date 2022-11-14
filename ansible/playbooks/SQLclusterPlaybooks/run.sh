#!/bin/sh
ansible-playbook step1.yml -b -K -i inventory
ansible-playbook step2.yml -b -K -i inventory
ansible-playbook step3-rhkvm.yml -b -K -i inventory


