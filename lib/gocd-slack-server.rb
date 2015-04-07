require 'slack-notifier'
require 'active_support/core_ext/hash'

module Gocdss
  class Server
    def initialize(gocd_addr:, slack_hook:, bot_name:, user_pass:)
      #Tracks by id
      @known_events = {}


      #Slack
      @notifier = Slack::Notifier.new slack_hook
      @notifier.username = bot_name

      #Address of gocd server
      @gocd_addr = gocd_addr
      @user_pass = user_pass
    end

    def process_event event
      update_known_events(event)
    end

    def update_known_events e
      label = e["label"]
      name = e["name"]

      revisions = e["build_cause"]["material_revisions"].map{|e|e["modifications"]}.flatten

      revisions.map! do |r|
        rev_info = {}
        rev_info["user"] = r["user_name"]
        rev_info["comment"] = r["comment"]
        rev_info["sha"] = r["revision"]

        rev_info
      end

      if @known_events[label+name]
        last_jobs = @known_events[label+name]["jobs"]
        jobs = get_jobs(e)

        if jobs != last_jobs
          @known_events[label+name]["jobs"] = jobs

          changed_jobs = jobs - last_jobs
          changed_jobs.each do |job|
            notify_job_changed job
          end
        end
      else
        @known_events[label+name] = {}
        @known_events[label+name]["commits"] = revisions
        @known_events[label+name]["name"] = name
        @known_events[label+name]["label"] = label
        @known_events[label+name]["jobs"] = get_jobs(e)
        notify_pipeline_start @known_events[label+name]
      end
    end

    def get_jobs e
      jobs = []

      stages = e["stages"]
      stages.each do |stage|
        stage["jobs"].each do |job|
          job_info = {}
          job_info["job_name"] = job["name"]
          job_info["state"] = job["state"]
          job_info["result"] = job["result"]
          job_info["stage_name"] = stage["name"]
          job_info["pipeline_name"] = e["name"]
          job_info["pipeline_label"] = e["label"]
          job_info["stage_try_counter"] = stage["counter"]
          jobs << job_info
        end
      end

      jobs
    end

    def start
      @notifications_enabled = false
      loop do
        sleep 3

        pipelines = Hash.from_xml(`curl -u #{@user_pass} #{@gocd_addr}/go/api/pipelines.xml`)
        pipeline_names = pipelines["pipelines"]["pipeline"].map{|e| e["href"]}.map{|e| e.scan(/pipelines\/(.*)\/stages.xml/)}.flatten
        pipeline_names.each do |pipe_name|
          if @user_pass
            hash = JSON.parse(`curl -u #{@user_pass} #{@gocd_addr}/go/api/pipelines/#{pipe_name}/history 2>/dev/null`)
          else
            hash = JSON.parse(`curl #{@gocd_addr}/go/api/pipelines/#{pipe_name}/history 2>/dev/null`)
          end
            events = hash["pipelines"]
            events.each do |event|
            process_event event
          end
        end

        #Enable first time around, but just keep it true forever after
        @notifications_enabled = true
      end
    end

    def notify_pipeline_start info
      title = "#{info["name"]} [#{info["label"]}]"
      text = ""
      info["commits"].each do |commit|
        text += "• *[#{commit["user"]}]* - #{commit["comment"].split("\n")[0]}"
      end
      link = @gocd_addr+"/go/pipelines/value_stream_map/#{info["name"]}/#{info["label"]}"
      slack(title: title, text: text, link: link, color: "good")
    end

    def notify_job_changed job_info
      if job_info["state"] == "Completed"
        title = "#{symbol_for_result job_info["result"]} - #{job_info["pipeline_name"]} [#{job_info["pipeline_label"]}] - #{job_info["stage_name"]}/#{job_info["job_name"]}"
        link = @gocd_addr+"/go/tab/build/detail/#{job_info["pipeline_name"]}/#{job_info["pipeline_label"]}/#{job_info["stage_name"]}/#{job_info["stage_try_counter"]}/#{job_info["job_name"]}#tab-console"
        #text = job_info["result"]
        text = job_info["result"]
        slack(title: title, text: text, link: link, color: color_for_result(job_info["result"]))

        if job_info["result"] == "Failed"

          fail_image = JSON.parse(`curl "http://api.giphy.com/v1/gifs/search?q=fail&api_key=dc6zaTOxFJmzC"`)["data"].sample["url"]
          @notifier.ping fail_image
        end
      end
    end

    def symbol_for_result result
      case result
      when "Passed"
        return ":smile:"
      when "Failed"
        return ":fu:"
      when "Cancelled"
        return ":raising_hand:"
      end
    end

    def color_for_result result
      case result
      when "Passed"
        return "good"
      when "Failed"
        return "danger"
      when "Cancelled"
        return "warning"
      end
    end

    def slack(title:, text:, link:, color:)
      return unless @notifications_enabled
      payload = {text: text, color: color, title: title, title_link: link, mrkdwn_in: ["text"]}
      @notifier.ping "", attachments: [payload]
    end
  end
end
