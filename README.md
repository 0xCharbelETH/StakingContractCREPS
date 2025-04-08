# CREPS Staking Contract

![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)  
![Polygon](https://img.shields.io/badge/Blockchain-Polygon-8247e5)  

## 🔹 Introduction

Ce dépôt contient le contrat intelligent de **staking** pour le token **$CREPS**, conçu pour permettre aux détenteurs de jalonner leurs tokens et gagner des récompenses à un **APY configurable**. Il est déployable sur le réseau **Polygon**.

## ⚙️ Fonctionnalités

- Staking et déstaking sécurisé
- Récompenses basées sur un APY annuel (Annual Percentage Yield)
- Période de verrouillage personnalisable
- Claim de récompenses à tout moment (même sans déstaking)
- Transfert des récompenses depuis un portefeuille dédié
- Sécurité renforcée avec `ReentrancyGuard` et `Ownable`

## 📜 Spécifications

| Paramètre | Description |
|----------|-------------|
| Token utilisé | $CREPS (ERC-20) |
| APY | Définissable par l’owner (ex: 200 = 200%) |
| Lock period | Durée (en secondes) avant autorisation de unstake |
| Reward wallet | Adresse séparée pour la distribution des récompenses |

## 🔐 Sécurité

- **ReentrancyGuard** protège les appels contre les attaques de réentrance.
- Seul le propriétaire peut modifier l’APY, le wallet de récompense, ou effectuer des retraits d’urgence.

## 🚀 Déploiement

1. **Cloner le dépôt**

```bash
git clone https://github.com/0xCharbelETH/creps-token.git
cd StakingContractCREPS
