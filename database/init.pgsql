-- =============================================
-- EXTENSIONS
-- =============================================
create extension if not exists "uuid-ossp";

-- =============================================
-- USER PROFILES (SUPABASE AUTH LINK)
-- =============================================
create table profiles (
    id uuid primary key references auth.users(id) on delete cascade,
    full_name text not null,
    role text check (role in ('admin', 'teacher')) not null,
    created_at timestamptz default now()
);

create index idx_profiles_role on profiles(role);

-- =============================================
-- INSTITUTES
-- =============================================
create table institutes (
    id uuid primary key default uuid_generate_v4(),
    name text not null,
    owner_admin_id uuid references profiles(id),
    created_at timestamptz default now()
);

create index idx_institutes_owner on institutes(owner_admin_id);

-- =============================================
-- ADMINS PER INSTITUTE (MULTI-ADMIN)
-- =============================================
create table institute_admins (
    institute_id uuid references institutes(id) on delete cascade,
    admin_id uuid references profiles(id) on delete cascade,
    primary key (institute_id, admin_id)
);

-- =============================================
-- TEACHER INVITATIONS
-- =============================================
create table teacher_invitations (
    id uuid primary key default uuid_generate_v4(),
    institute_id uuid references institutes(id) on delete cascade,
    email text not null,
    invited_by uuid references profiles(id),
    accepted boolean default false,
    created_at timestamptz default now(),
    unique (institute_id, email)
);

-- =============================================
-- TEACHERS PER INSTITUTE
-- =============================================
create table institute_teachers (
    institute_id uuid references institutes(id) on delete cascade,
    teacher_id uuid references profiles(id) on delete cascade,
    primary key (institute_id, teacher_id)
);

-- =============================================
-- ACADEMIC YEARS
-- =============================================
create table academic_years (
    id uuid primary key default uuid_generate_v4(),
    institute_id uuid references institutes(id) on delete cascade,
    year_label text not null,
    is_active boolean default false,
    unique (institute_id, year_label)
);

-- =============================================
-- CLASSES & SECTIONS
-- =============================================
create table classes (
    id uuid primary key default uuid_generate_v4(),
    institute_id uuid references institutes(id) on delete cascade,
    class_name text not null
);

create table sections (
    id uuid primary key default uuid_generate_v4(),
    class_id uuid references classes(id) on delete cascade,
    section_name text not null
);

-- =============================================
-- SUBJECTS
-- =============================================
create table subjects (
    id uuid primary key default uuid_generate_v4(),
    institute_id uuid references institutes(id) on delete cascade,
    name text not null
);

create index idx_subjects_institute on subjects(institute_id);

-- =============================================
-- PERIODS (TIMETABLE)
-- =============================================
create table periods (
    id uuid primary key default uuid_generate_v4(),
    institute_id uuid references institutes(id) on delete cascade,
    subject_id uuid references subjects(id),
    teacher_id uuid references profiles(id),
    class_id uuid references classes(id),
    section_id uuid references sections(id),
    day_of_week int check (day_of_week between 1 and 7),
    start_time time not null,
    end_time time not null
);

create index idx_periods_teacher on periods(teacher_id);
create index idx_periods_subject on periods(subject_id);
create index idx_periods_class on periods(class_id, section_id);

-- =============================================
-- STUDENTS (STATIC IDENTITY)
-- =============================================
create table students (
    id uuid primary key default uuid_generate_v4(),
    institute_id uuid references institutes(id) on delete cascade,
    roll_number text not null,
    registration_number text,
    full_name text not null,
    created_at timestamptz default now(),
    unique (institute_id, roll_number)
);

create index idx_students_institute on students(institute_id);

-- =============================================
-- STUDENT YEARLY ENROLLMENT (PROMOTION READY)
-- =============================================
create table student_enrollments (
    id uuid primary key default uuid_generate_v4(),
    student_id uuid references students(id) on delete cascade,
    academic_year_id uuid references academic_years(id),
    class_id uuid references classes(id),
    section_id uuid references sections(id),
    is_repeating boolean default false,
    promoted boolean default false,
    unique (student_id, academic_year_id)
);

create index idx_enrollments_class on student_enrollments(class_id, section_id);

-- =============================================
-- STUDENT SUBJECT ENROLLMENT (ACADEMY MODEL)
-- =============================================
create table student_subject_enrollments (
    student_id uuid references students(id) on delete cascade,
    subject_id uuid references subjects(id) on delete cascade,
    academic_year_id uuid references academic_years(id),
    enrolled_at timestamptz default now(),
    primary key (student_id, subject_id, academic_year_id)
);

create index idx_subject_students on student_subject_enrollments(subject_id);
create index idx_student_subjects on student_subject_enrollments(student_id);

-- =============================================
-- CLASS BASED ATTENDANCE (DATE ONLY)
-- =============================================
create table class_attendance (
    id uuid primary key default uuid_generate_v4(),
    attendance_date date not null,
    academic_year_id uuid references academic_years(id),
    class_id uuid references classes(id),
    section_id uuid references sections(id),
    teacher_id uuid references profiles(id),
    created_at timestamptz default now(),
    unique (attendance_date, class_id, section_id)
);

create table class_attendance_records (
    attendance_id uuid references class_attendance(id) on delete cascade,
    student_id uuid references students(id),
    status text check (status in ('present', 'absent', 'leave')),
    primary key (attendance_id, student_id)
);

create index idx_class_attendance_date on class_attendance(attendance_date);

-- =============================================
-- PERIOD BASED ATTENDANCE (DATE + TIME)
-- ONLY SUBJECT-ENROLLED STUDENTS
-- =============================================
create table period_attendance (
    id uuid primary key default uuid_generate_v4(),
    period_id uuid references periods(id),
    attendance_date date not null,
    marked_at timestamptz default now(),
    unique (period_id, attendance_date)
);

create table period_attendance_records (
    attendance_id uuid references period_attendance(id) on delete cascade,
    student_id uuid references students(id),
    status text check (status in ('present', 'absent', 'leave')),
    primary key (attendance_id, student_id)
);

create index idx_period_attendance_date on period_attendance(attendance_date);
