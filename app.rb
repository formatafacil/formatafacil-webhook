# encoding: UTF-8

require 'sinatra'
require 'json'
require 'fileutils'
require 'formatafacil/compila'
require 'formatafacil/otimizador_para_web'

# Configuring Your Server : https://developer.github.com/webhooks/configuring/

configure :production, :development do
  enable :logging
end

def cria_ou_atualiza_repositorio(bare_dir, full_name)
    logger.info "Criando ou atualizando o projeto: #{full_name}"
    if File.exist?(bare_dir)
      Dir.chdir(bare_dir) do
        system "git fetch"
        logger.info "Projeto atualizado com sucesso: #{full_name}"
      end
    else
      FileUtils::mkdir_p bare_dir
      system "git clone --mirror https://github.com/#{full_name} #{bare_dir}"
      logger.info "Projeto clonado com sucesso: #{full_name}"
    end
end

def extrai_arquivos_da_head(bare_dir, public_dir)
  FileUtils::rm_f public_dir
  FileUtils::mkdir_p public_dir
  Dir.chdir(bare_dir) do
    logger.info "Extraindo arquivos em #{public_dir}"
    system "git archive --format=tar --prefix=#{public_dir}/ HEAD | (cd ../../../ && tar xf -)"
  end
end

get '/artigo/:user/:repo/?' do |user, repo|
  @user = user
  @repo = repo
  @pdf_file = "/artigo/#{user}/#{repo}/artigo.pdf"
  @tex_file = "/artigo/#{user}/#{repo}/artigo.tex"
  @log_file = "/artigo/#{user}/#{repo}/artigo.log"
  @pdf_exists = File.exist?("#{settings.public_folder}/#{@pdf_file}")
  if @pdf_exists
    #File.read("public/#{pdf_file}")
    #redirect pdf_file
    #send_file File.join(settings.public_folder, pdf_file)
    #@data_modificacao = File.mtime(File.join(settings.public_folder, pdf_file))   #=> Tue Apr 08 12:58:04 CDT 2003
    @data_modificacao = File.mtime(File.join(settings.public_folder, @pdf_file)).strftime("%Y-%m-%d %H:%M:%S")
    erb :artigo, :format => :html5
  else
    "Não foi encontrado registro do repositório: '#{user}/#{repo}', você configurou o webhook?"
  end

end

post '/artigo' do
  push = JSON.parse(request.body.read)
  logger.info "I got some JSON: #{push.inspect}"
  
  full_name = push['repository']['full_name'] # edusantana/playground-asciidoc
  owner = full_name.split(/\//)[0] #edusantana
  repo_name = owner = full_name.split(/\//)[1] #playground-asciidoc
  working_dir = full_name
  bare_dir   = "bare/#{full_name}"
  public_dir = "public/artigo/#{full_name}"
    
  cria_ou_atualiza_repositorio(bare_dir, full_name)
  extrai_arquivos_da_head(bare_dir, public_dir)
   
  Dir.chdir(public_dir) do
    logger.debug "Executando formatafacil em #{public_dir}"
    
    system "formatafacil artigo"
    
    logger.info "Iniciando compilação de artigo.tex:"

    begin
      Formatafacil::Compila.new().compila_artigo
      logger.info "Artigo compilado com sucesso."

      logger.info "Otimizando para web: #{Formatafacil::ARTIGO_PDF}"
      Formatafacil::OtimizadorParaWeb.new(Formatafacil::ARTIGO_PDF).otimiza
    rescue => e
      logger.error e.message
    end
    
  end
  
end