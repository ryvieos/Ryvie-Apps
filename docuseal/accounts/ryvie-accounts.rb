# ryvie-accounts.rb — Fiche de gestion des comptes DocuSeal.
#
# Vit AVEC l'app (appstore) et s'exécute DANS le conteneur app-docuseal via
# `rails runner` : elle a donc un accès complet au modèle User (Devise) et à la
# base, sans dépendance externe. Ryvie ne fait que la déclencher (docker exec) et
# lire son résultat — il ne connaît ni le schéma ni le format de hash.
#
# DocuSeal hache via Devise (bcrypt). On réutilise Devise pour garantir la
# compatibilité au login.
#
# Sous-commandes (ARGV[0]) :
#   list                         -> JSON des comptes sur stdout
#   reset    (env RESET_ID/PWD)  -> change le mot de passe + vérifie -> "OK"/"FAIL"
#   verify   (env RESET_ID/PWD)  -> "OK" si le mot de passe correspond, sinon "NO"
#   provision (env DEFAULT_*)    -> crée le compte par défaut (idempotent) -> "DONE"
require 'json'

cmd = ARGV[0]

case cmd
when 'list'
  puts(User.all.map do |u|
    {
      id: u.id.to_s,
      email: u.email,
      isAdmin: (u.respond_to?(:admin?) ? !!u.admin? : (u.respond_to?(:role) ? u.role.to_s == 'admin' : false)),
    }
  end.to_json)

when 'reset'
  u = User.find(ENV['RESET_ID'])
  u.password = ENV['RESET_PWD']
  u.password_confirmation = ENV['RESET_PWD'] if u.respond_to?(:password_confirmation=)
  u.save!
  puts(u.reload.valid_password?(ENV['RESET_PWD']) ? 'OK' : 'FAIL')

when 'verify'
  u = (ENV['RESET_ID'].to_s.empty? ? nil : User.find_by(id: ENV['RESET_ID']))
  u ||= User.find_by(email: ENV['RESET_EMAIL']) unless ENV['RESET_EMAIL'].to_s.empty?
  puts(u && u.valid_password?(ENV['RESET_PWD']) ? 'OK' : 'NO')

when 'provision'
  email = ENV['DEFAULT_EMAIL']
  pwd = ENV['DEFAULT_PWD']
  uname = ENV['DEFAULT_USER']
  if User.find_by(email: email).nil?
    base = User.first
    acc = base ? base.account : (defined?(Account) ? Account.create!(name: 'Ryvie') : nil)
    u = User.new(email: email)
    u.first_name = uname if u.respond_to?(:first_name=)
    u.last_name = 'Ryvie' if u.respond_to?(:last_name=)
    u.role = (base ? base.role : 'admin') if u.respond_to?(:role=)
    (u.account = acc if acc) if u.respond_to?(:account=)
    u.password = pwd
    u.password_confirmation = pwd if u.respond_to?(:password_confirmation=)
    u.save!
  end
  puts 'DONE'

else
  warn "sous-commande inconnue: #{cmd}"
  exit 2
end
