FROM ruby:2.6.3

LABEL Name=raiseme-pluto Version=0.1.0

WORKDIR /app
ADD . /app

RUN bundle install

EXPOSE 4000

CMD ["bundle", "exec", "rackup", "--host", "0.0.0.0", "-p", "4000"]
