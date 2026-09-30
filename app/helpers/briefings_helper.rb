module BriefingsHelper
  def question_subject_label(subject)
    subject.is_a?(Engagement) ? "#{subject.ref} #{subject.title}" : subject.name
  end
end
