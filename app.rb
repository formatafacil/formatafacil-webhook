require 'sinatra'
require 'json'
require 'fileutils'

# Configuring Your Server : https://developer.github.com/webhooks/configuring/

configure :production, :development do
  enable :logging
end

def cria_ou_atualiza_repositorio(bare_dir, full_name)
    logger.info "Criando ou atualizando o projeto: #{full_name}"
    if File.exist?(bare_dir)
      Dir.chdir(bare_dir) do
        system "git fetch"
        logger.debug "Projeto atualizado com sucesso: #{full_name}"
      end
    else
      FileUtils::mkdir_p "bare/#{working_dir}"
      system "git clone --mirror https://github.com/#{full_name} #{bare_dir}"
      logger.debug "Projeto clonado com sucesso: #{full_name}"
    end
end

def extrai_arquivos_da_head(bare_dir, public_dir)
  FileUtils::rm_f public_dir
  FileUtils::mkdir_p public_dir
  Dir.chdir(bare_dir) do
    logger.debug "Extraindo arquivos em #{public_dir}"
    system "git archive --format=tar --prefix=#{public_dir}/ HEAD | (cd ../../../ && tar xf -)"
  end
end

post '/artigo' do
  push = JSON.parse(request.body.read)
  puts "I got some JSON: #{push.inspect}"
  
  full_name = push['repository']['full_name'] # edusantana/playground-asciidoc
  owner = full_name.split(/\//)[0] #edusantana
  repo_name = owner = full_name.split(/\//)[1] #playground-asciidoc
  working_dir = full_name
  bare_dir   = "bare/#{full_name}"
  public_dir = "public/artigos/#{full_name}"
    
  cria_ou_atualiza_repositorio(bare_dir, full_name)
  extrai_arquivos_da_head(bare_dir, public_dir)
   
  Dir.chdir(public_dir) do
    logger.debug "Executando formatafacil em #{public_dir}"
    system "formatafacil artigo"
    
    system "pdflatex -interaction=batchmode artigo.tex"
    system "pdflatex -interaction=batchmode artigo.tex"
  end
  
end