FROM ruby:3.3-slim

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

COPY Gemfile Gemfile.lock ./
COPY vendor/ vendor/

RUN bundle config set --local without 'development test' && \
    bundle install

COPY . .

EXPOSE 4567

CMD ["bundle", "exec", "ruby", "server.rb"]
